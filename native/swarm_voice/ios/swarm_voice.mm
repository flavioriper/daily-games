// The Swarm's call audio for iOS (docs/agents/bot.md, "Echo cancelling"): the
// mic and the Swarm's voice on one AVAudioEngine with Apple's voice processing
// on, so the echo canceller hears what the speaker plays and takes it out of
// the mic. Godot's own audio is the plain RemoteIO unit: .voiceChat over it
// cancels nothing. Up: 16 kHz int16 mono. Down: 24 kHz int16 mono. The same
// methods as the Android plugin (native/swarm_voice/android), polled by
// bot/call.gd every frame. Built by tools/build_swarm_voice.sh against
// ~/dev/godot-4.7-src's headers.

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/variant.h"

#import <AVFoundation/AVFoundation.h>
#include <os/lock.h>

#include <vector>

static const double UP_RATE = 16000.0;
static const double DOWN_RATE = 24000.0;
static const int CHUNK = 480; // frames a level is measured over, 20 ms at 24 kHz
static const int LEVELS = 4096;
static const int MIC_RING = 16000 * 2 * 4; // four seconds of mic bytes

struct VoiceState {
	os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
	std::vector<uint8_t> mic = std::vector<uint8_t>(MIC_RING);
	int mic_head = 0;
	int mic_size = 0;
	std::vector<int16_t> down = std::vector<int16_t>(24000 * 4);
	int down_head = 0;
	int down_size = 0;
	int64_t played = 0;
	float levels[LEVELS] = {};
	int64_t level_chunk = 0;
	int partial_count = 0;
	double partial_sum = 0.0;
};

class SwarmVoice : public Object {
	GDCLASS(SwarmVoice, Object);

	static SwarmVoice *singleton;

	VoiceState *state = nullptr;
	AVAudioEngine *engine = nil;
	AVAudioSourceNode *source = nil;
	AVAudioConverter *converter = nil;
	AVAudioFormat *up_format = nil;
	NSString *saved_category = nil;
	NSString *saved_mode = nil;
	AVAudioSessionCategoryOptions saved_options = 0;
	bool running = false;
	bool vp = false;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("start"), &SwarmVoice::start);
		ClassDB::bind_method(D_METHOD("echoCancelling"), &SwarmVoice::echo_cancelling);
		ClassDB::bind_method(D_METHOD("active"), &SwarmVoice::active);
		ClassDB::bind_method(D_METHOD("readMic"), &SwarmVoice::read_mic);
		ClassDB::bind_method(D_METHOD("pushVoice", "pcm"), &SwarmVoice::push_voice);
		ClassDB::bind_method(D_METHOD("clearVoice"), &SwarmVoice::clear_voice);
		ClassDB::bind_method(D_METHOD("played"), &SwarmVoice::played);
		ClassDB::bind_method(D_METHOD("queued"), &SwarmVoice::queued);
		ClassDB::bind_method(D_METHOD("level"), &SwarmVoice::level);
		ClassDB::bind_method(D_METHOD("stop"), &SwarmVoice::stop);
		ClassDB::bind_method(D_METHOD("micPermission"), &SwarmVoice::mic_permission);
		ClassDB::bind_method(D_METHOD("requestMic"), &SwarmVoice::request_mic);
	}

public:
	static SwarmVoice *get_singleton() { return singleton; }

	SwarmVoice() {
		singleton = this;
		state = new VoiceState();
	}

	~SwarmVoice() {
		stop();
		delete state;
		if (singleton == this) {
			singleton = nullptr;
		}
	}

	/// Opens the mic and the voice on one voice-processing engine. False when anything failed (the call falls back to Godot's mic, half duplex).
	bool start() {
		if (running) {
			return true;
		}
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		st->mic_head = st->mic_size = 0;
		st->down_head = st->down_size = 0;
		st->played = 0;
		st->level_chunk = 0;
		st->partial_count = 0;
		st->partial_sum = 0.0;
		memset(st->levels, 0, sizeof(st->levels));
		os_unfair_lock_unlock(&st->lock);

		AVAudioSession *session = [AVAudioSession sharedInstance];
		saved_category = session.category;
		saved_mode = session.mode;
		saved_options = session.categoryOptions;
		NSError *err = nil;
		AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetoothHFP;
		if (![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:options error:&err] || ![session setActive:YES error:&err]) {
			NSLog(@"SwarmVoice: session failed: %@", err);
			_restore_session();
			return false;
		}

		engine = [[AVAudioEngine alloc] init];
		AVAudioInputNode *input = engine.inputNode;
		if (![input setVoiceProcessingEnabled:YES error:&err]) {
			NSLog(@"SwarmVoice: voice processing failed: %@", err);
			engine = nil;
			_restore_session();
			return false;
		}
		vp = input.isVoiceProcessingEnabled;
		if (@available(iOS 17.0, *)) {
			// the game's own sounds are not turned down more than they must be
			AVAudioVoiceProcessingOtherAudioDuckingConfiguration ducking;
			ducking.enableAdvancedDucking = NO;
			ducking.duckingLevel = AVAudioVoiceProcessingOtherAudioDuckingLevelMin;
			input.voiceProcessingOtherAudioDuckingConfiguration = ducking;
		}

		// up: whatever the processed mic gives, converted to 16 kHz int16 mono
		AVAudioFormat *in_format = [input outputFormatForBus:0];
		up_format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:UP_RATE channels:1 interleaved:YES];
		converter = [[AVAudioConverter alloc] initFromFormat:in_format toFormat:up_format];
		if (converter == nil || in_format.sampleRate <= 0) {
			NSLog(@"SwarmVoice: no converter from %@", in_format);
			engine = nil;
			_restore_session();
			return false;
		}
		converter.downmix = YES;
		AVAudioConverter *conv = converter;
		AVAudioFormat *out_format = up_format;
		[input installTapOnBus:0
					bufferSize:1024
						format:in_format
						 block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
							 AVAudioFrameCount cap = (AVAudioFrameCount)(buffer.frameLength * UP_RATE / in_format.sampleRate) + 32;
							 AVAudioPCMBuffer *out = [[AVAudioPCMBuffer alloc] initWithPCMFormat:out_format frameCapacity:cap];
							 __block BOOL given = NO;
							 NSError *cerr = nil;
							 [conv convertToBuffer:out
											error:&cerr
							   withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount count, AVAudioConverterInputStatus *status) {
								   if (given) {
									   *status = AVAudioConverterInputStatus_NoDataNow;
									   return nil;
								   }
								   given = YES;
								   *status = AVAudioConverterInputStatus_HaveData;
								   return buffer;
							   }];
							 int n = (int)out.frameLength * 2;
							 if (n <= 0) {
								 return;
							 }
							 const uint8_t *bytes = (const uint8_t *)out.int16ChannelData[0];
							 os_unfair_lock_lock(&st->lock);
							 for (int i = 0; i < n; i++) {
								 st->mic[st->mic_head] = bytes[i];
								 st->mic_head = (st->mic_head + 1) % MIC_RING;
							 }
							 st->mic_size = MIN(MIC_RING, st->mic_size + n); // a stalled game drops the oldest, never lags
							 os_unfair_lock_unlock(&st->lock);
						 }];

		// down: the voice from a ring, through the same engine, so the canceller hears it
		AVAudioFormat *voice_format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:DOWN_RATE channels:1];
		source = [[AVAudioSourceNode alloc] initWithFormat:voice_format
											   renderBlock:^OSStatus(BOOL *silence, const AudioTimeStamp *ts, AVAudioFrameCount frames, AudioBufferList *list) {
												   float *outp = (float *)list->mBuffers[0].mData;
												   os_unfair_lock_lock(&st->lock);
												   int n = MIN((int)frames, st->down_size);
												   int len = (int)st->down.size();
												   for (int i = 0; i < n; i++) {
													   float v = st->down[(st->down_head + i) % len] / 32768.0f;
													   outp[i] = v;
													   st->partial_sum += (double)v * v;
													   if (++st->partial_count == CHUNK) {
														   st->levels[st->level_chunk % LEVELS] = (float)sqrt(st->partial_sum / CHUNK);
														   st->level_chunk++;
														   st->partial_count = 0;
														   st->partial_sum = 0.0;
													   }
												   }
												   st->down_head = (st->down_head + n) % len;
												   st->down_size -= n;
												   st->played += n;
												   os_unfair_lock_unlock(&st->lock);
												   for (int i = n; i < (int)frames; i++) {
													   outp[i] = 0.0f;
												   }
												   *silence = (n == 0);
												   return noErr;
											   }];
		[engine attachNode:source];
		[engine connect:source to:engine.mainMixerNode format:voice_format];
		[engine prepare];
		if (![engine startAndReturnError:&err]) {
			NSLog(@"SwarmVoice: engine failed: %@", err);
			[input removeTapOnBus:0];
			engine = nil;
			source = nil;
			_restore_session();
			return false;
		}
		running = true;
		NSLog(@"SwarmVoice: started, voice processing %d, mic %@", vp, in_format);
		return true;
	}

	/// The mic permission as iOS holds it: 0 not asked yet, 1 refused, 2 allowed.
	/// The screen asks this, never the mic's silence: Apple's voice processing
	/// gives exact zeros while it starts and while the Swarm talks, so a quiet
	/// allowed mic and a refused one sound the same (2026-11-07).
	int mic_permission() const {
		if (@available(iOS 17.0, *)) {
			switch ([AVAudioApplication sharedInstance].recordPermission) {
				case AVAudioApplicationRecordPermissionGranted:
					return 2;
				case AVAudioApplicationRecordPermissionDenied:
					return 1;
				default:
					return 0;
			}
		}
		switch ([AVAudioSession sharedInstance].recordPermission) {
			case AVAudioSessionRecordPermissionGranted:
				return 2;
			case AVAudioSessionRecordPermissionDenied:
				return 1;
			default:
				return 0;
		}
	}

	/// Shows the system's mic sheet when it was never answered; the answer is read back with micPermission.
	void request_mic() {
		if (mic_permission() != 0) {
			return;
		}
		if (@available(iOS 17.0, *)) {
			[AVAudioApplication requestRecordPermissionWithCompletionHandler:^(BOOL granted) {
				NSLog(@"SwarmVoice: mic permission %d", granted);
			}];
			return;
		}
		[[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
			NSLog(@"SwarmVoice: mic permission %d", granted);
		}];
	}

	/// The echo canceller is on the mic: the call may stay full duplex.
	bool echo_cancelling() const { return running && vp; }

	bool active() const { return running; }

	/// Every mic byte recorded since the last call (16 kHz int16 mono, whole samples).
	PackedByteArray read_mic() {
		PackedByteArray out;
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		int n = st->mic_size & ~1;
		if (n > 0) {
			out.resize(n);
			uint8_t *w = out.ptrw();
			int tail = (st->mic_head - st->mic_size + MIC_RING) % MIC_RING;
			for (int i = 0; i < n; i++) {
				w[i] = st->mic[(tail + i) % MIC_RING];
			}
			st->mic_size -= n;
		}
		os_unfair_lock_unlock(&st->lock);
		return out;
	}

	/// The Swarm's voice from the socket (24 kHz int16 mono), queued to play.
	void push_voice(const PackedByteArray &pcm) {
		if (!running) {
			return;
		}
		int n = pcm.size() / 2;
		if (n <= 0) {
			return;
		}
		const uint8_t *r = pcm.ptr();
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		int len = (int)st->down.size();
		if (st->down_size + n > len) {
			std::vector<int16_t> grown(MAX(len * 2, st->down_size + n));
			for (int i = 0; i < st->down_size; i++) {
				grown[i] = st->down[(st->down_head + i) % len];
			}
			st->down.swap(grown);
			st->down_head = 0;
			len = (int)st->down.size();
		}
		int at = (st->down_head + st->down_size) % len;
		for (int i = 0; i < n; i++) {
			st->down[(at + i) % len] = (int16_t)(r[i * 2] | (r[i * 2 + 1] << 8));
		}
		st->down_size += n;
		os_unfair_lock_unlock(&st->lock);
	}

	/// A `clear`: the queued voice is dropped; the speaker stops within one render (a few ms).
	void clear_voice() {
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		st->down_head = st->down_size = 0;
		os_unfair_lock_unlock(&st->lock);
	}

	/// Voice frames played on this call (24 kHz).
	int played() {
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		int64_t p = st->played;
		os_unfair_lock_unlock(&st->lock);
		return (int)p;
	}

	/// Voice frames handed over to play on this call, including those still queued.
	int queued() {
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		int64_t q = st->played + st->down_size;
		os_unfair_lock_unlock(&st->lock);
		return (int)q;
	}

	/// How loud the voice is right now: the RMS of the last 20 ms played, 0..1 of full scale.
	float level() {
		VoiceState *st = state;
		os_unfair_lock_lock(&st->lock);
		float v = (st->down_size > 0 && st->level_chunk > 0) ? st->levels[(st->level_chunk - 1) % LEVELS] : 0.0f;
		os_unfair_lock_unlock(&st->lock);
		return v;
	}

	void stop() {
		if (!running) {
			return;
		}
		running = false;
		[engine.inputNode removeTapOnBus:0];
		[engine stop];
		if (source != nil) {
			[engine detachNode:source];
		}
		source = nil;
		converter = nil;
		engine = nil;
		_restore_session();
		clear_voice();
	}

	void _restore_session() {
		if (saved_category == nil) {
			return;
		}
		NSError *err = nil;
		[[AVAudioSession sharedInstance] setCategory:saved_category mode:saved_mode options:saved_options error:&err];
		saved_category = nil;
		saved_mode = nil;
	}
};

SwarmVoice *SwarmVoice::singleton = nullptr;

static SwarmVoice *swarm_voice = nullptr;

void initialize_swarm_voice_module() {
	GDREGISTER_CLASS(SwarmVoice);
	swarm_voice = memnew(SwarmVoice);
	Engine::get_singleton()->add_singleton(Engine::Singleton("SwarmVoice", swarm_voice));
}

void uninitialize_swarm_voice_module() {
	if (swarm_voice) {
		memdelete(swarm_voice);
		swarm_voice = nullptr;
	}
}
