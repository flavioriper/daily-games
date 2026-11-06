package com.peeplet.swarmvoice;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.AudioTrack;
import android.media.MediaRecorder;
import android.media.audiofx.AcousticEchoCanceler;
import android.media.audiofx.AutomaticGainControl;
import android.media.audiofx.NoiseSuppressor;
import android.os.Build;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.List;

/**
 * The Swarm's call audio, both ways, on the phone's voice-call path
 * (docs/agents/bot.md, "Echo cancelling"). Godot's own mic is raw: no echo
 * cancelling, so the call had to send silence whenever the Swarm talked and
 * everything said over it was lost. Here the mic records with
 * VOICE_COMMUNICATION in MODE_IN_COMMUNICATION and the Swarm's voice plays on a
 * USAGE_VOICE_COMMUNICATION track, the way WebRTC (the browser's call) does it,
 * so the phone's echo canceller hears what the speaker plays and takes it out
 * of the mic. Up: 16 kHz int16 mono. Down: 24 kHz int16 mono.
 *
 * Polled from GDScript every frame (bot/call.gd): read_mic, push_voice,
 * played, written, level. No signals.
 */
public class SwarmVoicePlugin extends GodotPlugin {
	private static final String TAG = "SwarmVoice";
	private static final int UP_RATE = 16000;
	private static final int DOWN_RATE = 24000;
	private static final int CHUNK = 480; // frames a level is measured over, 20 ms at 24 kHz
	private static final int LEVELS = 4096; // chunks of level kept, ~80 s
	private static final int MIC_RING = UP_RATE * 2 * 4; // four seconds of mic bytes

	private final Object lock = new Object();
	private AudioManager audio;
	private int savedMode = AudioManager.MODE_NORMAL;
	private boolean savedSpeaker = false;
	private AudioRecord record;
	private AudioTrack track;
	private AcousticEchoCanceler aec;
	private NoiseSuppressor ns;
	private AutomaticGainControl agc;
	private Thread recorder;
	private Thread player;
	private volatile boolean running = false;

	// mic ring, written by the recorder thread, read by read_mic
	private final byte[] mic = new byte[MIC_RING];
	private int micHead = 0; // next write
	private int micSize = 0;

	// voice queue, written by push_voice, drained into the track by the player thread
	private byte[] down = new byte[DOWN_RATE * 2 * 4];
	private int downHead = 0; // next read
	private int downSize = 0;
	private long written = 0; // frames handed to the track
	private long base = 0; // frames counted as played before the last flush
	private final float[] levels = new float[LEVELS];
	private int partialCount = 0;
	private double partialSum = 0.0;
	private long levelChunk = 0;

	public SwarmVoicePlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "SwarmVoice";
	}

	/** Opens the mic and the voice on the call path. False when anything failed (the call falls back to Godot's mic, half duplex). */
	@UsedByGodot
	public boolean start() {
		synchronized (lock) {
			if (running) {
				return true;
			}
			Context ctx = getActivity();
			if (ctx == null) {
				return false;
			}
			try {
				audio = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);
				savedMode = audio.getMode();
				savedSpeaker = audio.isSpeakerphoneOn();
				audio.setMode(AudioManager.MODE_IN_COMMUNICATION);
				route();

				int inMin = AudioRecord.getMinBufferSize(UP_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
				record = new AudioRecord(MediaRecorder.AudioSource.VOICE_COMMUNICATION, UP_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, Math.max(inMin, UP_RATE * 2 / 5));
				if (record.getState() != AudioRecord.STATE_INITIALIZED) {
					throw new IllegalStateException("record not initialized");
				}
				int session = record.getAudioSessionId();
				if (AcousticEchoCanceler.isAvailable()) {
					aec = AcousticEchoCanceler.create(session);
					if (aec != null) {
						aec.setEnabled(true);
					}
				}
				if (NoiseSuppressor.isAvailable()) {
					ns = NoiseSuppressor.create(session);
					if (ns != null) {
						ns.setEnabled(true);
					}
				}
				if (AutomaticGainControl.isAvailable()) {
					agc = AutomaticGainControl.create(session);
					if (agc != null) {
						agc.setEnabled(true);
					}
				}

				int outMin = AudioTrack.getMinBufferSize(DOWN_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
				track = new AudioTrack.Builder()
						.setAudioAttributes(new AudioAttributes.Builder()
								.setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
								.setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
								.build())
						.setAudioFormat(new AudioFormat.Builder()
								.setEncoding(AudioFormat.ENCODING_PCM_16BIT)
								.setSampleRate(DOWN_RATE)
								.setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
								.build())
						.setTransferMode(AudioTrack.MODE_STREAM)
						.setBufferSizeInBytes(Math.max(outMin, DOWN_RATE * 2 / 10))
						.build();
				if (track.getState() != AudioTrack.STATE_INITIALIZED) {
					throw new IllegalStateException("track not initialized");
				}
				micHead = micSize = 0;
				downHead = downSize = 0;
				written = base = 0;
				levelChunk = 0;
				partialCount = 0;
				partialSum = 0.0;
				java.util.Arrays.fill(levels, 0f);
				record.startRecording();
				track.play();
				running = true;
			} catch (Exception e) {
				Log.w(TAG, "start failed: " + e);
				release();
				return false;
			}
			recorder = new Thread(this::recordLoop, "SwarmVoiceMic");
			recorder.setPriority(Thread.MAX_PRIORITY);
			recorder.start();
			player = new Thread(this::playLoop, "SwarmVoiceOut");
			player.setPriority(Thread.MAX_PRIORITY);
			player.start();
			Log.i(TAG, "started: aec=" + echoCancelling() + " ns=" + (ns != null) + " agc=" + (agc != null));
			return true;
		}
	}

	/** The phone's echo canceller is on the mic: the call may stay full duplex. */
	@UsedByGodot
	public boolean echoCancelling() {
		return aec != null && aec.getEnabled();
	}

	@UsedByGodot
	public boolean active() {
		return running;
	}

	/** Every mic byte recorded since the last call (16 kHz int16 mono, whole samples). */
	@UsedByGodot
	public byte[] readMic() {
		synchronized (lock) {
			int n = micSize & ~1;
			byte[] out = new byte[n];
			int tail = (micHead - micSize + MIC_RING) % MIC_RING;
			int first = Math.min(n, MIC_RING - tail);
			System.arraycopy(mic, tail, out, 0, first);
			System.arraycopy(mic, 0, out, first, n - first);
			micSize -= n;
			return out;
		}
	}

	/** The Swarm's voice from the socket (24 kHz int16 mono), queued to play. */
	@UsedByGodot
	public void pushVoice(byte[] pcm) {
		synchronized (lock) {
			if (!running || pcm == null || pcm.length == 0) {
				return;
			}
			if (downSize + pcm.length > down.length) {
				byte[] grown = new byte[Math.max(down.length * 2, downSize + pcm.length)];
				for (int i = 0; i < downSize; i++) {
					grown[i] = down[(downHead + i) % down.length];
				}
				down = grown;
				downHead = 0;
			}
			int at = (downHead + downSize) % down.length;
			for (int i = 0; i < pcm.length; i++) {
				down[(at + i) % down.length] = pcm[i];
			}
			downSize += pcm.length;
		}
	}

	/** A `clear`: the queued voice is dropped and what the track holds stops now. What was dropped counts as played. */
	@UsedByGodot
	public void clearVoice() {
		synchronized (lock) {
			downHead = downSize = 0;
			if (track != null && running) {
				try {
					track.pause();
					track.flush();
					base = written;
					track.play();
				} catch (Exception e) {
					Log.w(TAG, "clear failed: " + e);
				}
			}
		}
	}

	/** Voice frames played on this call (24 kHz). */
	@UsedByGodot
	public int played() {
		synchronized (lock) {
			if (track == null) {
				return (int) written;
			}
			long head = track.getPlaybackHeadPosition() & 0xffffffffL;
			return (int) Math.min(written, base + head);
		}
	}

	/** Voice frames handed over to play on this call, including those still queued. */
	@UsedByGodot
	public int queued() {
		synchronized (lock) {
			return (int) (written + downSize / 2);
		}
	}

	/** How loud the voice is right now: the RMS of the 20 ms the speaker is playing, 0..1 of full scale. */
	@UsedByGodot
	public float level() {
		int p = played();
		synchronized (lock) {
			long chunk = p / CHUNK;
			if (chunk >= levelChunk || levelChunk - chunk >= LEVELS) {
				return 0f;
			}
			return levels[(int) (chunk % LEVELS)];
		}
	}

	@UsedByGodot
	public void stop() {
		synchronized (lock) {
			running = false;
		}
		join(recorder);
		join(player);
		recorder = null;
		player = null;
		synchronized (lock) {
			release();
		}
	}

	@Override
	public void onMainDestroy() {
		stop();
	}

	private void route() {
		if (Build.VERSION.SDK_INT >= 31) {
			List<AudioDeviceInfo> devices = audio.getAvailableCommunicationDevices();
			AudioDeviceInfo pick = null;
			int[] prefer = {AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER};
			for (int type : prefer) {
				for (AudioDeviceInfo d : devices) {
					if (d.getType() == type) {
						pick = d;
						break;
					}
				}
				if (pick != null) {
					break;
				}
			}
			if (pick != null) {
				audio.setCommunicationDevice(pick);
			}
		} else if (!audio.isWiredHeadsetOn() && !audio.isBluetoothScoOn()) {
			audio.setSpeakerphoneOn(true); // the call path's default is the earpiece
		}
	}

	private void recordLoop() {
		byte[] buf = new byte[UP_RATE * 2 / 50]; // 20 ms
		while (running) {
			int n = record.read(buf, 0, buf.length);
			if (n <= 0) {
				try {
					Thread.sleep(5); // an error read returns at once: never spin
				} catch (InterruptedException e) {
					return;
				}
				continue;
			}
			synchronized (lock) {
				for (int i = 0; i < n; i++) {
					mic[micHead] = buf[i];
					micHead = (micHead + 1) % MIC_RING;
				}
				micSize = Math.min(MIC_RING, micSize + n); // a stalled game drops the oldest, never lags
			}
		}
	}

	private void playLoop() {
		byte[] buf = new byte[CHUNK * 2];
		byte[] quiet = new byte[CHUNK * 2];
		while (running) {
			int n;
			synchronized (lock) {
				n = Math.min(buf.length, downSize);
				for (int i = 0; i < n; i++) {
					buf[i] = down[(downHead + i) % down.length];
				}
				downHead = (downHead + n) % down.length;
				downSize -= n;
				if (n > 0) {
					measure(buf, n);
					written += n / 2;
				}
			}
			if (n > 0) {
				track.write(buf, 0, n); // blocks while the track is full: the thread keeps time with the speaker
			} else {
				try {
					Thread.sleep(5);
				} catch (InterruptedException e) {
					return;
				}
			}
		}
	}

	private void measure(byte[] buf, int n) {
		for (int i = 0; i + 1 < n; i += 2) {
			int s = (short) ((buf[i] & 0xff) | (buf[i + 1] << 8));
			double v = s / 32768.0;
			partialSum += v * v;
			partialCount++;
			if (partialCount == CHUNK) {
				levels[(int) (levelChunk % LEVELS)] = (float) Math.sqrt(partialSum / CHUNK);
				levelChunk++;
				partialCount = 0;
				partialSum = 0.0;
			}
		}
	}

	private void join(Thread t) {
		if (t == null) {
			return;
		}
		try {
			t.join(500);
		} catch (InterruptedException ignored) {
		}
	}

	private void release() {
		running = false;
		if (record != null) {
			try {
				record.stop();
			} catch (Exception ignored) {
			}
			record.release();
			record = null;
		}
		if (track != null) {
			try {
				track.pause();
				track.flush();
				track.stop();
			} catch (Exception ignored) {
			}
			track.release();
			track = null;
		}
		if (aec != null) {
			aec.release();
			aec = null;
		}
		if (ns != null) {
			ns.release();
			ns = null;
		}
		if (agc != null) {
			agc.release();
			agc = null;
		}
		if (audio != null) {
			if (Build.VERSION.SDK_INT >= 31) {
				audio.clearCommunicationDevice();
			} else {
				audio.setSpeakerphoneOn(savedSpeaker);
			}
			audio.setMode(savedMode);
			audio = null;
		}
	}
}
