# The Swarm's call server (`server/bot`)

The live voice call with the Swarm, the friendly companion made of light who
lives in the game: the phone streams the mic over a websocket to
`server/bot` (Deepgram Flux hears, `gpt-6-luna` answers, ElevenLabs speaks,
pre-made clips fill the gaps), and the player's memory travels in the
`hello` and comes back as `memory` messages. How it is built: `server/bot/README.md`.
The one-shot hold-to-talk button that came first is `swarm-talk.md`.

## Testers only (2026-11-05)

**The Swarm is never in a store build** (the user: "hide swarm in
production, only available at firebase and ios testflight"). The Bot chip
shows only on a testers' build, `BotCall.testers_build()`:
`OS.is_debug_build()` (Android's App Distribution APKs, CI and
`tools/deploy_android.sh`, are debug exports; Play's AAB from
`tools/release_android.sh` is release) or the `beta` feature tag. iOS
TestFlight and the App Store share one binary, so the tag is baked in at
export: **TestFlight = `tools/export_ios.sh --release --beta`**, App Store =
`tools/export_ios.sh --release`, each then `tools/upload_ios.sh`. The upload
numbers a store build `<commit count>.1` and a beta build `<commit count>`,
so **only a build ending in .1 may be picked for App Review**; a beta build
sent there would put the Swarm in the store. The chip is the only door to
the call screen (`ui/menu.gd`), so hiding it hides the Swarm. Checked
2026-11-05: a `--beta` export's pck carries `_custom_features = "beta"`, a
plain one none, and `export_presets.cfg` comes back unchanged.

## The phone's side

`bot/bot_screen.gd` (the Bot chip, teens and adults only:
`ui/menu/category_row.gd` `entries()`) is the room: the back button, the
log, the status line, the demo pills (offline only, a row under the memory
pill), the memory pill top right. Opening it asks for the mic on Android, takes
`Backend.token()` and dials `bot/call.gd`; no token, a `--script` run or a
refused mic is the offline face (the intro demo, the line after five
seconds). `bot/swarm_face.gd` is the face cut out of the old Swarm tab;
the screen drives it with `set_live`, `set_state`, `set_level`, `say` and
`reveal`, and the `tool` frames with its `apply_*`. A call's `ended` is
counted against the calls the screen let go of, so a late one from a
closed call is ignored; a new call waits for the last one's bye to finish.
`memory` frames are applied whenever they come, after the screen closed
too. Draw calls on the screen offline with the intro talking: 26 (the old
tab with its mic button: 36), 2026-11-05; live with the talk button, its hint
and three lines of subtitles: 39.

**Awake, screen on, background** (2026-11-05): while the screen's phase is
dialing, connecting or live it holds `Power.hold("bot", true)` (the game would
rest after twenty idle seconds, 30 fps and the face's idle stopped; a hold
also keeps the shade's unfocus from resting the frame) and
`DisplayServer.screen_set_keep_on(true)`; both go the moment the phase leaves
those three (`_set_phase`), on close and when the screen is freed. The demo
holds nothing. `NOTIFICATION_APPLICATION_PAUSED` ends a call at once
(`BotCall.stop(true)`: bye sent, nothing waited for, the memory frames the
server was still writing are lost) and never redials; on
`NOTIFICATION_APPLICATION_RESUMED` the face says `SWARM_L1` again and the
status line says `BOT_REDIAL`. A tap on the face after any call ended (the
hour's limit excepted), or after an offline open, calls again. Knocks: GOOD
when the session comes, TAP when a tap cuts the voice (TICK when nothing was
playing), TAP when the back button hangs up a call.

**The final review's fixes** (2026-11-05): the Bot chip shows only once
`BotCall.configured()` (the address is no longer the placeholder `BOT_URL`;
the env `BOT_URL` and `user://bot_url` are read in debug builds only, so a
store build dials only the constant). `stop()` silences the voice at once
(queue dropped, a `clear`'s fade, nothing after the bye is played) and waits
up to 30 s for `bye_ack` (the server's end budget is 25). The socket pings
every 10 s; a call live 16 minutes says bye by itself. The talk button held
with the mic giving only exact zeros for 1.5 s (iOS answers a refused mic
with silence) ends the call with `BOT_MIC_REFUSED`. A `bye` the screen did
not ask for (the server's cap, its error close) says `BOT_REDIAL`; 4409 and
4429 do not redial. The talk button lets go on focus out (shade, overlay),
when the memory sheet opens, and when the screen leaves the tree. The server
logs `bye received` and, when a call gets no summary, why (`hub <status>`,
`no client`, `N lines of M messages`), never the words.

**The memory sheet** (2026-11-05, the plan's Task 14): `bot/memory_sheet.gd`
extends `ui/hud/sheet.gd` (paper, also over the dark room): facts as chips,
episodes as rows under them, newest first by `since`/`at`, `BOT_KNOWN_NONE`
when empty, scrolling past 820 px. A tap asks on the bin's card
(`Dialog`, `flat_host._ask_clear`'s recipe; `BOT_KEEP` the sun button,
`BOT_FORGET` the pill) and forgets through `BotMemory.forget` (facts and
episodes alike) and `BotCall.forget` during a call. The ask is a child of the
sheet and the sheet the room's last child, so Android's back closes the ask,
then the sheet, then the room; the room's `close()` closes the sheet too. A
`memory` frame refreshes the open sheet (`sheet.refresh()`, deferred); the call
goes on under it. 58 draw calls with the sheet up over the offline room, both
drivers. While the room is up the ad banner stands aside (`Ads.hold("bot")`,
`docs/agents/ads-and-purchase.md`). Every line a tap redials from
(`BOT_DROPPED`, `BOT_OFFLINE`) ends on that tap.

**Hands free, like a call** (2026-11-05 evening, the user: "replace the mic
button with a hands free like a call, i think it's better"). The hold-to-talk
button of that afternoon (7f08e4d8: the round mic, `BOT_HOLD`, `_draw_mic`)
is gone. Half duplex, as before it: `_drive` sends
`BotCall.send_silence((speaking or playing) and not _opened)` every frame, so
the mic is open whenever the Swarm is not talking and zeros go up while it
talks or its voice still plays (Godot's mic has no echo cancelling: a full
duplex mic would hand Flux the Swarm's own words from the speaker). A tap on
the face cuts the voice and opens the mic at once. The server did not
change: persona-studio was always free hand on the same pipeline (Flux ends
the turn; `MinWords(2)` and the stop word start one). The dead-mic check
(`BotCall.mic_dead`, `BOT_MIC_REFUSED`) now only fires on a mic that has
never given a non-zero sample in the call (`_mic_alive`): a refused mic
never does, a phone gating a quiet room to zeros did once. Draw calls on the
live room with three lines of subtitles: 27 (39 with the button).

## The ten voices (2026-11-06)

Boyd's low rasp is gone. The user's rule for any Swarm voice: "a warm,
playful and kind voice, full of energy but also supportive. It should sound
like someone ready to play, but that can't wait to know you more." Picked by
ear from a listening page (https://claude.ai/artifact/Q1ZaoVAfb4nTBWQy5rEF75,
the same hello in each candidate from ElevenLabs' shared library, filtered
by those tags and by a year's use), a woman's and a man's voice per accent:

| | woman | man |
|---|---|---|
| en, US | Jessica | Drew |
| en, UK (GB, IE) | Lucy | Conversational Joe |
| pt, Brazil | Raquel | Will (supportive) |
| es, Latin America | Daniela | Mario |
| es, Spain (ES) | Raquel | Rafa N |

The ids, accents and regions are `server/bot/seeds/swarm_voices.json`, read
by `bot/cards.py` and `tools/gen_swarm_voice.py`; the game's
`bot/bot_voice.gd` keeps the same accents and regions in its own consts.
These are community voices: their owners can take them down, which is the
licence review still owed.

- **Which one a player hears.** No button (the user: "we not gonna use
  buttons, so player can ask to switch voice"). The first time it is a coin
  toss (the user: random per player), on the phone (`BotVoice.gender()`,
  kept in `user://bot_voice`) so the intro and the call agree; the hello
  carries `voice` and `region` (`OS.get_locale()`'s country). The server
  answers every session with `tool {name: voice, cmd}` and the phone keeps
  it; an old phone with no `voice` gets a server coin toss the same way.
- **Switching mid-call**: the `voice` tool (`female`/`male`, same language
  and accent). `run_call` loads the other voice's clips beside the call's at
  the start (`ClipPlayer.keep`), so a switch is `ClipPlayer.use` plus a
  `TTSUpdateSettingsFrame` aimed at the TTS: ElevenLabs' dialogue socket
  registers the voice per reply, so the next sentence is in the new voice
  with no reconnect. The tool's result tells the model which forms to use
  for itself from then on.
- **Speaking of itself**: `load_card` adds one line to the identity
  (Portuguese and Spanish mark it: feita/feito, hecha/hecho), and
  `lines_<lang>_female` in the seed overrides the clip lines that do
  ("eu sou a Swarm", "obrigada", "Quase pronta", "Casi lista", the
  disclosure). The intro has `SWARM_L1_F`; `BotVoice.GENDERED` lists the
  keys with a feminine row.
- **Clips**: ten server sets, `voices/swarm/<language>-<accent>-<gender>/`
  (45 clips, ~3 MB each), rendered with `studio.clips.render_clips` over
  `clip_card(load_card(...))` for every voice; an accent whose set is
  missing speaks with the language's first accent. The intro: 80 mp3s,
  `assets/voice/swarm/<KEY>_<set>.mp3`, `python3 tools/gen_swarm_voice.py`,
  then `godot --headless --path . --import`.
- **Owed**: a deploy (`tools/deploy_bot.sh`, person-run: the image bakes the
  new sets, and the live server still expects the old `en`/`pt`/`es`
  folders; an old server ignores the new hello fields, and an old phone, such
  as TestFlight 2184, ignores the `voice` tool frame, so either pairing
  works); hearing a switch on a real call; the pt/es feminine lines by a
  native speaker. Checked 2026-11-06: all ten ids speak on the call's own
  Text-to-Dialogue socket, one after another on one connection (a switch),
  with no voice added to the account.

## Fillers only while a slow tool works; subtitles off (2026-11-06)

The user: the filler phrases "work fine into a call but not that fine into
here"; keep them only "when the agent has to check for something that can
take longer, like 'let me think' or 'hmmm', but not needed for plain
replies". `PolicySteer(gap_fillers=False)` (only `voice/bot.py` passes it;
the studio and the tests keep the old clock): no `acks`, no `learned` line,
no bridge/thinking/stall gap clock on a plain reply, the Jev steer line
still goes in. A slow screen tool (`slow_call`: `see`, or `draw` with a
`subject`) started before the model has said a word gets one `thinking`
clip, then one `stalls` at `stall_after_s` if still nothing; a tool called
after words gets nothing. `voice` joined `SILENT_TOOLS` (it was getting the
typing cue). At most one thinking line a player turn (`_thought`, reset
when the player speaks): a draw and the look after it are one wait. To
listen for on the first real call: `_answering` is set when the text frame
reaches `AfterLLM`, `on_function_calls_started` fires inside the LLM
service; if the event wins, a thinking line follows the model's own "let me
draw that" (the same race reach_owner always had).

Subtitles: "completely different from what the agent says... keep the
subtitle off till user ask for a subtitle". `SwarmFace.subtitles` (false)
hides the `_words` label only; `said` and the line still drive the talking
look and the reveal clock. Not debugged; the likely cause for whoever turns
them on: pipecat pushes a sentence's `AggregatedTextFrame` when the TTS
starts synthesising it, which with a fast LLM is while an earlier sentence
is still playing in the phone's buffer, and `bot_screen.gd`'s `said`
replaces the line and resets `_mark` each time, so the caption runs ahead
of the voice. Clip lines were checked: every kind's texts line up with its
manifest (en-us-female).

## Echo cancelling: why the phone call felt worse than persona-studio (2026-11-05 night)

The user: "Bot here can't properly understand pauses, i talk and he answer 3
phrases later ... it doesn't sound smooth or human like the persona studio
one". **The server is not why**: `server/bot/voice/bot.py` builds the same
pipeline as persona-studio's (Flux, Listener, steer, LLM, ElevenLabs, clips;
same `COMMIT_EOT`, `strategies()`), and `seeds/swarm.json` differs from
`flavio.json` only in persona and lines. **The phone's audio was**: the
browser opens its mic with `echoCancellation`, `noiseSuppression` and
`autoGainControl` (persona-studio `static/call.js`), so the call is full
duplex: a pause and more words, or talking over the voice, reach Flux and the
pipeline's barge-in merges them. Godot's mic is raw (iOS `RemoteIO`, not the
voice-processing unit; Android OpenSL with no voice preset), so the screen had
to send zeros whenever the Swarm talked, and everything said over it was
lost: the Swarm answered the first half of a thought while the rest never
arrived. Godot 4.7's `AudioStreamPlaybackMicrophone` also reads its small ring
with no check against the write pointer (read in the source, not measured on
a phone).

**The fix is the phone's call path, both ways**: echo cancelling only works
when the canceller sees what the speaker plays, so the Swarm's voice plays
through the same path as the mic. `native/swarm_voice/` is the plugin,
`tools/build_swarm_voice.sh` builds it into `addons/swarm_voice/` (the AARs
are committed, as Firebase's; `android/` is not in git), and
`addons/swarm_voice/export_plugin.gd` puts it in Android exports.

- **Android** (`SwarmVoicePlugin.java`, the WebRTC recipe): `MODE_IN_COMMUNICATION`,
  `AudioRecord` from `VOICE_COMMUNICATION` at 16 kHz with
  `AcousticEchoCanceler`, `NoiseSuppressor` and `AutomaticGainControl` on its
  session when the phone has them, the voice on a `USAGE_VOICE_COMMUNICATION`
  `AudioTrack` at 24 kHz; the route is a headset when one is there, else the
  loudspeaker (the call path's default is the earpiece);
  `MODIFY_AUDIO_SETTINGS` comes in the AAR's manifest. Mode and route are put
  back at the call's end. The game polls it each frame (`readMic`,
  `pushVoice`, `clearVoice`, `played`, `queued`, `level`); logcat tag
  `SwarmVoice` prints `started: aec=… ns=… agc=…`.
- **`bot/call.gd`** uses it when `Engine.has_singleton("SwarmVoice")` and
  `start()` succeeds; otherwise (desktop, a failed start, the
  probe's test tone) Godot's mic and generator as before. `consumed()`,
  `playing()` and `level()` read the plugin then, so the subtitles and the
  face keep pace with the speaker.
- **The gate is conditional**: `bot_screen.gd` sends silence while the Swarm
  talks only when `BotCall.full_duplex()` is false, which is true on the
  plugin with the echo canceller on. A debug build can force it for a call
  with earbuds: `BOT_FULL_DUPLEX=1` or the file `user://bot_full_duplex`.
- **Music** is already held for the whole call (`Music.hold("bot")`): on iOS
  the canceller only removes what plays through its own unit, so nothing of
  the game's may play during a call.
- **iOS** (`native/swarm_voice/ios/swarm_voice.mm`, the same methods):
  one `AVAudioEngine` with `setVoiceProcessingEnabled(true)` on the input
  node (set while stopped; one I/O node turns on both), session
  `.playAndRecord` / `.voiceChat` / `.defaultToSpeaker` + Bluetooth HFP, put
  back at the call's end; the mic tap through an `AVAudioConverter`
  (downmix) to 16 kHz int16, the voice from an `AVAudioSourceNode` reading a
  ring (that is the canceller's reference), ducking of other audio at its
  minimum on iOS 17+. `.voiceChat` alone over Godot's `RemoteIO` cancels
  nothing. `tools/build_swarm_voice.sh --ios` compiles it against
  `~/dev/godot-4.7-src` with the iOS template's defines (`IOS_ENABLED
  APPLE_EMBEDDED_ENABLED UNIX_ENABLED COREAUDIO_ENABLED THREADS_ENABLED`, plus
  `DEBUG_ENABLED` for the debug one, `NDEBUG` for release) into
  `ios/plugins/swarm_voice/SwarmVoice.{debug,release}.xcframework` (device
  arm64, simulator arm64 + x86_64), enabled as `plugins/SwarmVoice=true` in
  the iOS preset. Checked 2026-11-05: the debug export links for the
  x86_64 simulator and an arm64 device, and a `--export-release` project
  links the release one for a device; **never run**: the iOS 26 simulator no
  longer runs x86_64 apps and Godot 4.7's simulator template has no arm64,
  so the first run is a TestFlight build on a phone. Watch there that the
  game's own sounds come back after a call (the session is put back).
- **Owed on the phone**: speaker on, talk over the Swarm mid-sentence (it
  stops, `clear` comes), pause mid-thought and go on (one turn, not two);
  check logcat says `aec=true` on the ROG; on iOS (TestFlight) the same, the
  device log says `SwarmVoice: started, voice processing 1`.

## The screen tools are dials, not tricks (2026-11-06)

A tester asked the Swarm to disappear; it said it would try and did nothing.
No tool could do it (intensity floored at 0.2, dots at the face's 691,
`move` keeps the face on screen), and the prompt listed the tools by verb, so
a request with no matching name fell through. The user: "they should be
generic enough to let the agent be creative". Now:

- `tone` intensity goes to **0** (`bot/swarm_face.gd` `INTENSITY`, the server
  clamps to 0..1.8): every dot, the halo, rings and bloom scale with it, so 0
  is gone from the screen while the call and the voice go on. The result says
  so; `seconds` brings it back on its own, and reopening the room resets to 1.
  Builds before this clamp 0 to 0.2 (a faint ghost).
- `PHONE` in `voice/prompt.py` names each tool as a dial and gives mixes as
  examples (hide = intensity 0, peek = corner + dim + look, excited = burst +
  flash, shy = thin + dim + glance away, sleep = doze + dim), with the rule:
  do the closest mix at once and say what you did, never "I'll try" and
  nothing, "can't" only when nothing comes close.
- `move` and `dots` point at `tone` 0 for vanishing whole.

The same day, second pass ("check how we can make others tools way more open
to agent creativity", then "do all"):

- **`perform`**, a routine: `steps` each any mix of swarm, move, dots, tone,
  draw (rows/name/clear) and `wait`, `repeat` 1-20, `back` (default) puts
  eyes, place, size, speed, colour, dots and face back, `stop` ends one. The
  server checks each step with that tool's own handler and sends `at`
  offsets; the phone (`apply_perform`, `_perf_fire`) fires them with the
  same `apply_*` a single call uses. Not `_run_script`: that one waits while
  the face speaks and ends in `_rest`. At most 120 s, 40 written steps.
- **swarm** gains `eyes` (0 shut .. 1.5 wide, eased, `seconds` for a
  moment), `blink`, `wink` left/right (per eye by `_ex`).
- **move** gains `size` (0.4-1.8, `_scale` multiplies sc, the cloud, halo,
  rings, room pool, clamp and `on_face`; `_R` is untouched), `speed`
  (0.25-3, the spring and its cap), and `peek-<edge>` (half off) and
  `off-<edge>` (4.2 radii off) spots; a picture still stays on screen. `to`
  is optional now.
- **draw** gains `frames` (2-12 same-size drawings, `frame_seconds`, `loops`):
  the server sends them as a `perform` of rows, and redrawing over a picture
  moves the same dots to the new shape, so frames flow, no flicker.
- Every `seconds` shares one cap, 0.5-120. Near misses are acted on, not
  refused (`_nearest`: "lef" is left, "vilet" violet, "hide" off-right),
  and common colour words map to a tone or hex (`COLOUR_WORDS`).
- Intensity 0 also closes the rings and the room's pool (`minf(_inten, 1)`):
  before, the rings stayed at 0.
- The voice's expression (`seeds/swarm.json`): 21 deliveries (whispers,
  mischievously, dramatically, singing, slowly...) and 9 sounds (laughs,
  giggles, gasps, hums...), 2 tags a reply, all in the character rule;
  pipecat writes them as ElevenLabs audio tags, subtitles drop them. Unheard.
- Old phone builds would drop these without a word while the Swarm said it
  did them, so the hello now carries `screen` (`bot/call.gd` SCREEN_LEVEL,
  2); a hello without it gets `Toolbox.screen_level` 1 and `_too_new` refuses
  perform, eyes/blink/wink, size, speed, peek/off spots, frames and intensity
  under 0.2 with "the app on this phone is too old for that".
- A call that ends (`set_live(false)`) brings the face back to rest: the
  routine dropped, the dials at 1, then `_rest()` (centre, green at 1, N dots,
  no picture), so a call never leaves the room empty or the face off screen.
- With a picture showing, `peek-*`/`off-*` go to that side instead (a picture
  stays on screen).
- Probe: `tests/_probe_swarm_dials.gd` (untracked), 13 checks and snapshots.

## A friend who talks about anything; the room trimmed; it wakes (2026-11-06)

The user: "too robotic, not natural, it's too expressive even for small
things", and it "should not talk about the puzzles (unless user ask, just like
any subject), it only lives inside the daily game because it's the easier way
to test the prototype". The Swarm is "a supportive, funny and full of jokes
agent called swarm, that talks about any subject, love to hear histories from
players. Players will probably use to practice a new language."

- **Persona** (`seeds/swarm.json`): the identity no longer says it lives in a
  puzzle game or asks how the puzzles are going; it talks about anything,
  loves stories, jokes from what was just said, is supportive without syrup,
  never brings up the game unless the player does, and with a learner recasts
  a slip in its own reply instead of correcting it, explaining only when
  asked or stuck. Style: match the player's energy, calm by default, small
  things get small reactions, short replies, not a question every turn.
- **Natural speech** (`voice/prompt.py`): the scripted quotas ("echo their
  topic in a fragment", one "uh", "I mean" once in four replies) are gone;
  OpenAI's realtime prompting guide notes a model overuses sample phrases
  until it sounds robotic. In their place a variety rule: never two replies
  opening the same way, no pattern of reactions, fillers or praise. The
  `[knowledge:` rule says those lines are background, used only when they
  answer the question, never a reason to steer the talk; the body's own
  moves are for big news, a real laugh or a goodbye, and small.
- **Audio tags**: one a reply (was two), 11 deliveries (dramatically,
  singing, whispers, slowly, quickly, amazed, delighted, surprised,
  reassuring and cute dropped) and 4 sounds (laughs, chuckles, sighs, hums),
  plus a guidance line in `voice/bot.py`: most replies carry no tag, a short
  or ordinary one never. Stability stays 0.5: a clip's file name hashes it,
  so changing it re-renders all 450 clips (a dial to try by ear if it still
  sounds dramatic).
- **Greeting** without "I live in this little puzzle game"; the ten greeting
  clips re-rendered (`render_clips`, only the greeting was new) and the old
  ones deleted. `knowledge/*/swarm.md` says the same; the Neon copy is
  updated only by `tools/sync_swarm_knowledge.py` (person-run, production).
- **Language practice**: the call's language is still the game's (Flux
  `general-en` for en, `general-multi` otherwise), so a learner sets the game
  to the language they practise; no switching mid-call.
- **The room**: the memory pill and sheet (`bot/memory_sheet.gd`, the
  `BOT_KNOWN_*`, `BOT_FORGET`, `BOT_KEEP` rows, `_shot_menu.gd`'s `bot sheet`)
  and the tool log in the bottom corner are gone (the user: "remove the what
  he remembers button and the bottom actions debug"); forgetting is asked out
  loud. The demo pills sit on the back button's row.
- **It wakes**: "while swarm is loading, keep the particles random on screen,
  when it's ready they form it, as he woke up". `open()` puts the face to
  `sleep(true)`: the field drifts, the boot clock waits. The `session` frame,
  or any offline end (no token, mic refused), calls `sleep(false)`: the
  gather plays from its start, the face forms 1.3 s later with its eyes shut
  and they open after 0.7 s. A face already formed (a redial) never sleeps.
  Probe: `tests/_probe_swarm_sleep.gd` (untracked).
- **Deployed 2026-11-06** on the user's word: revision `peeplet-bot-00006-xv9`
  (image `32e41ea0-20261106160333`, 100% traffic, `/health` 200) and the
  knowledge synced to production Neon (59 rows a language, the new swarm.md
  in, the old line gone). **Owed**: hearing a real call; the pt/es greetings
  by a native ear.

## The tool bench: luna, terra, sol (2026-11-06)

`tools/swarm_bench.py` with `tools/swarm_bench_cases.yaml` (15 cases, en/pt/es) puts the same player lines
through the real Swarm card (`load_card`, screen on), `system_prompt`, `Toolbox(phone=True, screen_level=2)`
and the typed tool loop (`tool_reply`), once per model, with the call's settings (`CHAT_REASONING`,
500 completion tokens). Rules score every run: right tool, intent (checked on what the phone was told,
after the Toolbox's clamps), valid calls (a mapped near miss is half), honest (no "I did it" with nothing
that worked), restraint (no tools on plain chat, at most four calls), speech (50 words, no banned phrases),
language. The `judge: true` cases are also compared pairwise, blind, both orders, by `--judge` (sol by
default, which is a contestant: the rule table is the verdict, the judge is colour). It does not measure
the eye (stubbed), memory or style notes, speech recognition or barge-in. Run from `server/bot` with
`OPENAI_API_KEY` set (it bills the production OpenAI account); `--fake` checks the scoring offline. Output:
`runs.jsonl`, `judge.jsonl`, `report.md` under `--out`.

## Who hears the recorded greeting; the first call's warm-up (2026-11-06)

The recorded greeting ends "What should I call you?", so it asked the user's name on every call although the
memory had it (the memory itself was fine: the name was pinned on turn 1). Now only a **new player** (the hello's
memory has no facts and no episodes) hears the greeting and disclosure clips. A **returning player** is greeted by
the model (the user's call): `voice/bot.py` `greet()` adds `welcome_back(store)` (the newest 12 facts, the last
two calls) as a system note and queues a `GreetingFrame`, which `PolicySteer` passes straight to the model (no
turn for Jev, memory or outcomes). luna wrote "Hi, Flavio! Lovely to see you again. How're the word puzzles
going?" in 0.9 to 3 s (en, pt, es); the disclosure is not repeated.

The first call on a fresh instance took 15 s from connect to the pipeline running (15:01 UTC, revision 00004's
first call, three hours after it started): the voice pipeline is imported on first use and the embedding model
loaded on the first hello. `bot/app.py` `warm_call()` now loads both, and the memory gate, on a worker thread at
startup. Each call prints one stdout line, durations only: `{"call_setup_ms": {memory_ms, returning, setup_ms,
connected_ms, first_voice_ms}}` (loguru keeps warnings, so this is a plain print).

## Testing a call locally

`BOT_TEST_PAGE=1 uv run python server.py` serves `GET /test`
(`server/bot/static/test.html`): paste a Firebase id token, keep or edit the
memory JSON, Call, talk, Bye. `memory` events rewrite the memory box, the
way the phone's file would change. Without `BOT_TEST_PAGE=1` there is no
`/test`. Keys go in the server's environment only: `OPENAI_API_KEY`,
`ELEVENLABS_API_KEY`, `DEEPGRAM_API_KEY`, `JEV_API_KEY`; `BOT_LEDGER=<file>`
is where the cost rows are copied (RAM only otherwise).

## What a minute costs

2026-11-05, the first run with real keys: a scripted English call (three
short questions, "remember that I like chess", a heart drawn; 52 s of
socket time), priced from its ledger rows with `prices.yaml`:
**$0.0174 for the call, $0.020 a minute.** ElevenLabs $0.0087 (217
characters; the clips are pre-made and cost nothing per call), Deepgram
Flux $0.0068 (billed on socket time, silence included), the eye judging
the drawing $0.0015, `gpt-6-luna` chat $0.0002 (12.6k prompt tokens, 97%
cache reads), memory $0.0002, Jev $0.0001. A short Portuguese call came to
$0.018 a minute (no Jev). A chattier call scales with the Swarm's own
speech: at about 450 spoken characters a minute it is near $0.027.

## Deploy

The call server runs on Cloud Run as `peeplet-bot` (the Swarm is not a
Peeplet character; the service keeps the name), project `daily-games-420bf`,
region `us-central1`. **Person-run**: an agent session writes the files and
runs none of this. The files: `server/bot/cloudbuild.yaml`,
`tools/deploy_bot.sh`, `server/bot/Dockerfile`, `tools/public_invoker.sh`
(which now takes a service name). There is no trigger: a push to `main`
does not deploy the bot, only `tools/deploy_bot.sh` does.

What the service is: `--max-instances=1 --min-instances=1 --cpu=2
--memory=2Gi --no-cpu-throttling --timeout=3600 --session-affinity
--concurrency=4` (4 is a placeholder, step 9 measures it); the bucket
`daily-games-420bf-peeplet-bot` mounts at `/data` (`STUDIO_DATA`), and
`BOT_LEDGER=/data/ledger.sqlite` is where the cost rows are copied (the
process keeps them in RAM and copies them there at each call end, below).
Five secrets,
named `peeplet-bot-*` in Secret Manager: `OPENAI_API_KEY`,
`DEEPGRAM_API_KEY`, `ELEVENLABS_API_KEY`, `JEV_API_KEY`, `NEON_SWARM_URL`.
`BOT_LOG_LEVEL` stays at its WARNING default (DEBUG logs what is said) and
`BOT_TEST_PAGE` is never set. The image bakes both embedding models into
`FASTEMBED_CACHE_PATH` (the device memory's English one and the shared
layer's multilingual one) and ships `voices/`: without the clips every call
is refused with 4409.

**Min instances 1** (2026-11-05 evening, the user: "keep min 1"; applied
with `gcloud run services update --min-instances=1`, revision
`peeplet-bot-00002-bx9`, and in `cloudbuild.yaml`). The user found the
answers slow beside persona-studio's demo: both calls that day had landed on
a fresh instance (`Starting new instance. Reason: AUTOSCALING`), about 18 s
from the instance's start to the socket being accepted. One warm instance,
2 vCPU without CPU throttling, is billed around the clock. Per-turn timings
are not logged (`breakdown()` logs the kind only), so what a warm turn costs
in production is not measured yet.

**Deployed 2026-11-05** (steps 3-8 run by the user): `https://peeplet-bot-ao7js3tmhq-uc.a.run.app`, image `5cbc455e-20261105175016`; the production `swarm` database on Neon's production branch, 59 knowledge rows a language; `/health` 200, a bad token closes 4401. `BotCall.BOT_URL` points at it, so the Bot chip shows in every build (Teen band and up). `tools/public_invoker.sh` was not executable; it is now.

The steps, in order. Each block is for a terminal on the Mac.

1. **Settle the admin account.** The navlio account was denied on
   2026-11-04; the firebase CLI deploys as `flavio@hypertradeworx.xyz`.
   Log in as an owner of the project and check:

   ```
   gcloud auth login
   gcloud config set account <the owner account>
   gcloud projects describe daily-games-420bf --format 'value(projectId)'
   ```

2. **Enable the services** (idempotent):

   ```
   gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com --project daily-games-420bf
   ```

3. **The production `swarm` database on Neon** (project `peeplet`, id
   `shy-mud-44712747`, the production branch): create the database in the
   Neon console (or `neon databases create --org-id org-young-lake-36988118 --project-id shy-mud-44712747 --branch production --name swarm`; the `neon` CLI, not `neonctl`, is the one on this Mac),
   copy its connection string, then apply the schema and sync the curated
   knowledge once. The URL goes in the environment of these commands only,
   never in a file or the shell history (`read -s` below):

   ```
   read -s NEON_SWARM_URL; export NEON_SWARM_URL
   cd server/bot && uv run python ../../tools/sync_swarm_knowledge.py --schema
   cd ../..
   ```

   `--dry-run` first shows what would be written. Later knowledge edits are
   the same command without `--schema`.

4. **The five secrets.** Keys come from the Mac's keychain or the
   providers' consoles; `read -s` keeps them off the screen. `NEON_SWARM_URL`
   is still exported from step 3:

   ```
   for pair in openai:OPENAI_API_KEY deepgram:DEEPGRAM_API_KEY elevenlabs:ELEVENLABS_API_KEY jev:JEV_API_KEY; do
     name=${pair%%:*}; var=${pair##*:}
     printf "%s: " "$var"; read -s value; echo
     printf %s "$value" | gcloud secrets create "peeplet-bot-$name" --data-file=- --replication-policy=automatic --project daily-games-420bf
   done
   printf %s "$NEON_SWARM_URL" | gcloud secrets create peeplet-bot-neon-swarm-url --data-file=- --replication-policy=automatic --project daily-games-420bf
   ```

5. **The bucket, the Artifact Registry repo and the service account:**

   ```
   gcloud storage buckets create gs://daily-games-420bf-peeplet-bot --location us-central1 --uniform-bucket-level-access --project daily-games-420bf
   gcloud artifacts repositories create peeplet-bot --repository-format docker --location us-central1 --project daily-games-420bf
   gcloud iam service-accounts create peeplet-bot --display-name "Peeplet bot (the Swarm's call server)" --project daily-games-420bf
   ```

6. **Grants.** The service account reads its five secrets and writes the
   bucket; Cloud Build's account deploys the service as it:

   ```
   P=daily-games-420bf
   SA=peeplet-bot@$P.iam.gserviceaccount.com
   gcloud storage buckets add-iam-policy-binding gs://$P-peeplet-bot --member serviceAccount:$SA --role roles/storage.objectAdmin
   for s in openai deepgram elevenlabs jev neon-swarm-url; do
     gcloud secrets add-iam-policy-binding peeplet-bot-$s --member serviceAccount:$SA --role roles/secretmanager.secretAccessor --project $P
   done
   NUM=$(gcloud projects describe $P --format 'value(projectNumber)')
   for BUILDER in $NUM@cloudbuild.gserviceaccount.com $NUM-compute@developer.gserviceaccount.com; do
     gcloud projects add-iam-policy-binding $P --member serviceAccount:$BUILDER --role roles/run.admin --condition=None
     gcloud projects add-iam-policy-binding $P --member serviceAccount:$BUILDER --role roles/artifactregistry.writer --condition=None
     gcloud iam service-accounts add-iam-policy-binding $SA --member serviceAccount:$BUILDER --role roles/iam.serviceAccountUser --project $P
   done
   ```

   (Only one of the two builder accounts is the one Cloud Build uses on
   this project; granting both is harmless, and a "does not exist" on one
   can be ignored.) If the organisation disables the automatic Editor grant
   to those default accounts, the build account may also need
   `roles/logging.logWriter` on the project (the build logs to Cloud
   Logging only) and read on `gs://daily-games-420bf_cloudbuild` (where
   `gcloud builds submit` stages the source), for example
   `roles/storage.objectViewer` on that bucket.

7. **Build and deploy:**

   ```
   tools/deploy_bot.sh --project daily-games-420bf
   ```

   It refuses to run without the project named, copies `content/pixel_garden.json`
   fresh into `server/bot/content/`, tags the image with the commit and the
   time, and runs `gcloud builds submit`.

8. **Open the service** (first deploy only; the players are anonymous
   Firebase users, the bot checks their id token itself):

   ```
   tools/public_invoker.sh peeplet-bot
   ```

   It prints the health answer, expected `{"ok":true}` with 200.

9. **Check and measure** (done with the person, not by the build):
   `curl https://<service-url>/health`; the test page against the service is
   `BOT_TEST_PAGE=1`, which production never sets, so a call is tested
   from a local `server.py` pointed at the same keys, or from the phone.
   Concurrency: two calls at once, watch CPU in Cloud Run metrics, then
   change `--concurrency=4` in `cloudbuild.yaml` and record the measured
   figure here: **not measured yet**.

The ledger (2026-11-05, final review): one per process (`Deps.ledger`,
`studio.ledger.open_ledger`), SQLite in RAM, so a row's commit never waits
on the Cloud Storage mount. At start the process reads back the copy at
`BOT_LEDGER` (one it cannot read is left alone and never saved over: that
process keeps its rows in RAM only); at each call end a worker thread
copies every row there with SQLite's backup API (into a local temp file,
then onto the mount, then a rename), and shutdown makes a last copy and
closes it. Known risk: the mount has no file locking, so with more than one
instance the copies would overwrite each other; with `--max-instances=1`
that cannot happen. Rows from a call that ends with the instance killed
before its copy are lost; acceptable for cost rows.
