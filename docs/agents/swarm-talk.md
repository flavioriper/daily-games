# Talking to the swarm

The user, 2026-11-05: "I should be able to talk to the swarm", then, after a
day's detour through voices made on the phone itself (Qwen3-TTS, Kokoro and
Whisper in a GDExtension; measured and dropped, "not the right moment",
kept on the branch `archive/swarm-local-voice-2026-11-05`): "keep the way
it was with elevenlabs and deepgram, let's just keep the voice feature".

A round mic button above the subtitles in the swarm room: hold, speak, let
go (`ui/menu/swarm_talk.gd`, wired in `ui/menu/swarm_tab.gd`).

1. The mic is an `AudioStreamMicrophone` on a `SwarmMic` bus at -80 dB with
   an `AudioEffectCapture`; on release it is averaged down to 16 kHz 16-bit
   mono. `audio/driver/enable_input` and the RECORD_AUDIO permission are on
   in every build since (a store build asks for the microphone too).
2. Deepgram `nova-3` hears it in the game's language (REST, one request).
3. `gpt-6-luna` (low reasoning) answers in one or two spoken sentences, the
   game's language, the last twelve turns kept.
4. ElevenLabs says it in the swarm's voice (Boyd, `eleven_v4_turbo`,
   stability 0.5, as `tools/gen_swarm_voice.py`) `with-timestamps`, so the
   reply plays through the same path as the pre-made lines: words appear as
   said, the analyser drives the face.

The face listens while the button is held and thinks until the reply's
audio is back; the log in the corner shows what was heard and each step's
time. Off the Mac: Deepgram took 1.5 s for a 3 s line.

## Keys

Dev keys on the user's own phone only, never in the repo or the APK
(the user's call, 2026-11-05: "dev key in this debug build only"). Pushed
with adb into the app's storage:

    adb push ~/.config/<deepgram|openai|elevenlabs>/api_key /data/local/tmp/k
    adb shell "run-as com.peeplet.daily sh -c 'mkdir -p files/swarm_keys; cat /data/local/tmp/k > files/swarm_keys/<name>'"
    adb shell rm /data/local/tmp/k

A missing key is named in the log when the mic is pressed. `run-as` needs
the debuggable build (`tools/deploy_android.sh --local`, then
`adb install -r -d`; the phone has Play's higher versionCode).

The last thing the mic heard is kept as `user://swarm_last_heard.pcm` (16 kHz s16 mono) for checking: `adb exec-out run-as com.peeplet.daily cat files/swarm_last_heard.pcm`. The Mac speaking beside the phone arrives at about -37 dBFS and Deepgram still reads it.
