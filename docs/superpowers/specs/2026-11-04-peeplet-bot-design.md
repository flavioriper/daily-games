# Peeplet Bot: a friend in the game who talks and remembers

**Date:** 2026-11-04
**Status:** design, Flavio's calls taken 2026-11-04 (two rounds, below); the
plan is `docs/superpowers/plans/2026-11-04-peeplet-bot-plan.md`. The calls
marked *(my call)* were made while writing and can be overturned.

## Intent

A player opens the bot from the first screen, talks to it out loud and hears
it answer in a real voice, at the quality of Persona Studio's demo
(`~/dev/hokipoki/persona-studio`, the "Flavio" persona). It is a friend, not
an assistant: it is curious about the player, remembers what they tell it
across days, and never pretends to have done anything it has not. What it
remembers lives on the player's phone and nowhere else.

The port starts from Persona Studio's call pipeline (Deepgram Flux hears,
OpenAI answers, ElevenLabs speaks, the swarm shows) and from Daily's Swarm
tab (`ui/menu/swarm_tab.gd`, the futuristic face of 2026-11-04). No
documents, no calendar, no email, no twin.

## Decided by Flavio (2026-11-04)

- **Body:** the swarm face in its dark room, as the Swarm tab draws it now.
  The Peeplet model is not the body for this version.
- **Brain:** keep OpenAI, as Persona Studio does (`openai:gpt-6-luna`).
- **Cost:** unlimited for now. No daily cap per player. The server still
  limits a player to one call at a time and a few calls an hour, and the
  service has an instance ceiling, which is the bill's ceiling.
- **Voice:** fully speech to speech. The player talks and hears the
  answer, through ElevenLabs with the Flavio persona's voice settings, the
  same quality as the demo. Not device text-to-speech, not text first.
- **Server:** a trimmed fork of Persona Studio under `daily/server/bot/`,
  its own Cloud Run service in `daily-games-420bf` (second round).
- **Warm start:** none for now. `min-instances` 0; the first caller after
  idle sees a waking-up face and waits for the cold start; the client's
  connect timeout allows for it (sixty seconds). A standing instance is a
  later call, with its monthly bill.
- **Who may open it:** only past the age gate (`core/age_gate.gd`). The
  chip is hidden for a player who answered under thirteen or has not
  answered yet.
- **Admin account:** Flavio named `andressa.t@navlio.io`. Verified
  2026-11-04: that account is denied `projects.get`, `run.services.list`,
  `secretmanager.secrets.list` and `cloudfunctions.locations.list` on
  `daily-games-420bf` today, while the firebase CLI on this Mac is logged in
  as `flavio@hypertradeworx.xyz` and deployed the functions on 2026-11-03
  through it. Session two's person-run steps start by settling which account
  holds the project (the navlio one may need roles, or a fresh
  `gcloud auth login`).

## Goals

1. A call from the phone: tap to start, talk, hear the answer in under two
   seconds, interrupt by talking or tapping, tap to hang up.
2. The bot remembers: facts about the player and a summary of each past
   call, carried across days, stored only on the device.
3. "Forget that" works, out loud and from a list the player can read.
4. English, Portuguese and Spanish, following the game's locale.
5. The face does what it says: look, glance, move and idle through the same
   two tools the demo's agent has, reworded for a phone; and two more of
   Daily's own (2026-11-05): draw a picture with its dots, grow or thin
   the swarm, and change its tone and glow.
6. Nothing in the game dials out from a harness or the suite.

## Non-goals

- Documents, RAG, email, calendar, reaching a real person: the agent tools
  of the demo are not ported. The bot has the four screen tools and memory.
- A Peeplet body, a typed chat, a text composer. Voice only; subtitles are
  a readout, not an input.
- Accounts: the identity is Daily's anonymous Firebase uid. Memory does not
  follow a player to a new phone.
- Per-player behaviour learning (Jev deltas, corrections): see "The policy
  layer" below.
- Caps, purchases, a paid tier. Nothing spends gold.
- A website page or the desktop.

## Anti-goals

- Anything about the player stored on a server past the end of the call:
  no transcripts, no facts, no summaries, no per-user model state. The
  ledger records costs per uid and nothing a player said.
- The bot claiming to remember what it did not retrieve, or claiming to be
  human when sincerely asked.
- A call that keeps running when the screen is off or the app is in the
  background.
- Harness runs that reach the network.

## Where the voice server lives

The pipeline is Python on Pipecat; it cannot be a Godot module. Flavio's
call: **a trimmed fork of Persona Studio under `daily/server/bot/`**,
deployed as its own Cloud Run service, `peeplet-bot`, in the game's project
`daily-games-420bf`. Chosen over a "bot mode" in Persona Studio because:

- the studio's `main` deploys the Sam/Daniel demo on every push; a bot
  change must not risk a demo day;
- the auth (Firebase token, not a studio cookie), the memory contract
  (device-fed, not Neon), identity, limits and scaling all differ;
- the game's project already holds the Firebase identity the token comes
  from, and the ledger of what is deployed there (`docs/agents/turns-and-backend.md`).

The fork records the source commit of persona-studio it was cut from, so a
fix there can be carried over by hand. `server/.gdignore` already keeps
Godot out of `server/`; `server/bot/` sits beside `server/functions/`.

The alternative, a second service deployed from the persona-studio repo with
a `BOT_MODE` flag, was turned down for the risks above.

**Unverified (2026-11-04):** the active gcloud account on this Mac cannot
list Cloud Run services in either project, so Persona Studio's deploy state
could not be checked. Its `cloudbuild.yaml` says push to main deploys to
Cloud Run in `us-central1` with secrets for OpenAI, Deepgram, ElevenLabs,
Soniox, Jev, the studio token and Neon; none of those secrets exist in
`daily-games-420bf` yet.

**One box, for now *(my call)*.** `max-instances` 1 and `concurrency` set
to the calls one 2-CPU instance carries (measured in session two, likely
three or four): the studio keeps its call count and its hourly limits in
process, and its ledger in a SQLite file, and none of that holds across
instances. One instance is the bill's ceiling and keeps both honest. The
ledger goes on a mounted bucket (`STUDIO_DATA`, as the studio mounts
`/data`) so cost rows survive a scale to zero. More than one instance is a
later change that moves the limits to Firestore, which the project already
has.

## The pieces

```
phone (Godot, bot/)                        peeplet-bot (Cloud Run, server/bot/)
----------------------------------         ------------------------------------
BotScreen  the dark room, the face,  <--ws--> /ws/bot   Firebase token -> uid
           subtitles, back, memory             hello: memory, language
           sheet, states                       Pipecat: Flux -> steer -> LLM
Call       mic -> 16 kHz PCM frames   --bin-->          -> ElevenLabs -> PCM
           24 kHz PCM -> speaker      <--bin--           tools: swarm, move
           JSON events                <--json-- said, state, tool, memory, clear
BotMemory  user://bot_memory.json              DeviceStore: in RAM for the
           facts, episodes, forget             call, fed by hello, diffs out
```

### The client, `bot/` *(my call on layout)*

A new folder, as `peeplet/` and `puzzles/` are, reachable from the categories
row where the Swarm chip is today (`ui/menu/category_row.gd`, key `swarm`
becomes `bot`; the locale key `BAR_SWARM` is reworded).

- `bot/bot_screen.gd`: the screen. The room, the face, the one back button,
  the subtitles near the foot, the quiet action log in the corner, and a
  small "what I know about you" button that opens the memory sheet. It
  holds `Music.hold("bot", true)` and `Power` (below) while open. Opening
  it starts a call; the back button ends it. Nothing else is on screen.
- `bot/swarm_face.gd`: the body, cut out of today's `ui/menu/swarm_tab.gd`
  (the sim, the shaders, the bloom, `apply_swarm`, `apply_move`,
  `apply_draw`, `apply_dots`, `apply_tone` and `ui/menu/swarm_picture.gd`, the
  states listening / thinking / speaking, the level from the Swarm bus's
  analyser). The tab's `SCRIPT` replay stays as the face's offline mode:
  it is what a harness and the suite run, and what a player sees when the
  call cannot connect (with the words saying so).
- `bot/call.gd`: one call over `WebSocketPeer`. Static, woken only by
  `BotScreen` on a real device, after `Backend` has an id token; unstarted
  means offline, the rule `core/backend.gd` keeps.
  - Mic: `audio/driver/enable_input=true` in `project.godot`; an
    `AudioStreamPlayer` with an `AudioStreamMicrophone` on its own `Mic`
    bus, muted, with an `AudioEffectCapture`; frames pulled every process
    tick, mixed to mono, resampled from the mix rate to 16 kHz, sent as
    little-endian int16 in ~20 ms binary frames. The bus's volume stays
    at zero so the phone never plays the mic.
  - Speaker: an `AudioStreamGenerator` at 24 kHz on the existing `Swarm`
    bus (its analyser already drives the face), fed from binary frames;
    `clear` fades what is queued over 50 ms and drops the rest, as
    `static/call.js` does.
  - Permissions: Android `RECORD_AUDIO` in `export_presets.cfg` and
    `OS.request_permission("RECORD_AUDIO")` before the first call; iOS
    `NSMicrophoneUsageDescription` in `additional_plist_content`. A refusal
    shows the offline face with a line that says why.
  - Duplex: decided by the first spike (below). The fallback is
    half-duplex: while the bot speaks, the client sends silence frames and
    a tap on the face interrupts (sends `interrupt`, the server clears).
- `bot/bot_memory.gd`: the device store. `user://bot_memory.json` holding
  `facts` (`id`, `text`, `since`, `valid_to`), `episodes` (`id`, `at`,
  `summary`) and `language`. Sent whole in `hello`; every `memory` event
  from the server is applied and saved at once, so a dropped call loses
  nothing already told. The sheet lists facts and past calls as chips; a
  tap on a chip forgets it locally and, during a call, tells the server.
  The file is on the device only: it is not in the backend queue, not in
  analytics, not in a backup the game makes.
- `bot/subtitles.gd`: the words of each `said` event appear at the pace of
  the audio actually played: the server sends the text when the TTS of a
  sentence starts, the client reveals characters in proportion to audio
  frames consumed against the sentence's expected length. No word timings
  exist in the Dialogue TTS path today; if Pipecat exposes them, use them.

### The server, `server/bot/` *(my call on the cut)*

Persona Studio minus the studio: keep `voice/` (the call, Flux, the steer,
the pace, the clip player, foley stripped of room sounds), `policy/`
(see below), `memory/` (gate, embed, recall, consolidate, turn), the parts
of `studio/` a call needs (card, brains, clips, prices, ledger), `agent/tools.py`
cut to the screen tools (the two, plus `draw`, `dots`, `tone` and `see`). Drop the pages, compile, calibration UI, Google,
documents, ingest, Neon, the show and talk views, the desk.

- **Auth.** `/ws/bot` takes the Firebase id token in the first message
  (`hello`), verifies it against Google's public certificates for project
  `daily-games-420bf`, and uses the uid as `user_id`. No token, bad token,
  or a uid already on a call: close `4401`. Over the hourly limit: `4429`.
- **`hello`** `{token, memory: {facts, episodes}, language, name?}`. The
  server answers `session` and starts the pipeline. Memory arrives whole
  because the server has none.
- **`bye`** *(my call)*. The back button sends `bye` rather than closing:
  the server stops the pipeline, runs the call's `end()` (summarise, promote
  lasting notes) with the socket open, sends the resulting `memory` events,
  then closes. The face shows a remembering state for those seconds, with a
  six-second cap on the client, after which it closes anyway. A call that
  ends by the app going to the background, a dropped network or a kill
  loses the episode and the promoted facts of that call; facts added
  mid-call were already saved on the device as they arrived.
- **The gate is the base gate for everyone *(my call)*.** The studio's
  `hub.gate_for` and `teach_drop` keep a per-user memory gate that learns
  from "forget that"; the bot runs one gate, nothing learned, and a forget
  only removes the fact. The fork needs a `DeviceHub` (gate, thresholds,
  `ensure`, `attach`/`detach`, `redact` as no-ops) as well as the
  `DeviceStore`.
- **Calibration *(my call)*.** The socket refuses a card without an
  accepted calibration, and the steer reads its default decision. The
  peeplet seed carries a hand-written `calibration` block (`accepted`
  true, a `default_decision` of execute / standard / warm / ack no,
  `delta_norm` 0, an empty `slice`) rather than a run through the studio's
  calibration flow. `models/base.pt` ships in the image; `holdout.parquet`
  does not.
- **DeviceStore.** The methods `MemoryTurn` uses on `hub.store`
  (`facts_for`, `add_fact`, `expire_fact`, `episodes_for`, `add_episode`,
  `update_episode`, `clear_notes`, `clear_stale_notes`) implemented over
  the in-RAM copy fed by `hello`, embedding facts and episodes with
  fastembed at call start (a few milliseconds each). Every write emits a
  `memory` event over the socket: `{op: add|update|forget|episode, id,
  text}`. The call's short-term notes and `end()` (summarise the call,
  promote lasting notes) stay as they are, and their results go out the
  same way before the socket closes. After the socket closes, the server
  holds nothing of the call.
- **Nothing persists about a player** except the ledger's cost rows keyed
  by uid. The events log (`deps.events`), which records `said` text, is
  off in the bot; the policy learner's per-user deltas are not written.
- **Events pushed, not polled.** The home page polls `/events` every
  500 ms; the phone gets `said` (text, sentence by sentence as TTS
  starts), `state` (listening / thinking / speaking), `tool` (the swarm and
  move commands, applied by the client exactly as today's `SCRIPT` is),
  `memory`, `clear`, `sfx` (dropped on the phone), as JSON on the socket.
- **The card.** A new seed, `server/bot/seeds/peeplet.json`, not Flavio's:
  its own identity ("a friend made of light who lives in this puzzle game,
  curious about the person, remembers what they share, never a product
  pitch"), its own greeting, `agent: false`, `disclose: true` (it says it
  is an AI after the greeting; the prompt already forbids claiming to be
  human), `room: null`, `language` from `hello`. Voice: the Flavio voice
  (`gfRt6Z3Z8aTbpLfexQ7N`, `eleven_v4_turbo`) with the kinder settings the
  Swarm tab uses today (stability 0.5, friendly / cheerful / gentle
  delivery tags) *(my call: he asked for the kinder voice that day; the
  studio's 0.35 calm / warm / laugh is one constant away)*.
  Its lines (acks, bridges, backchannels, thinking, stalls) are rendered
  to clips at deploy as the studio does, in en, pt and es.
- **The two screen tools**, reworded for a phone: `look` keeps `ahead`,
  the eight directions and `point`; `idle` keeps `ahead`, `wander`, `doze`;
  `move` keeps `centre`, the sides, the corners and `point`. `cursor`,
  `input` and `panel:` go, with the `[screen:` note. The client's
  `apply_swarm` and `apply_move` already take the rest.
- **Four more screen tools** (the user, 2026-11-05: "let the agent draw any
  pixel image using the particles", "also add tool to agent spawn more
  particles, or despawn it"). The phone side is built and probed in the
  Swarm tab (`apply_draw`, `apply_dots`, `apply_tone`,
  `ui/menu/swarm_picture.gd`); the
  server validates and passes the command through as `tool {name, cmd}`,
  as it does `swarm` and `move`. The phone answers a bad command with an
  error of its own, so the server's checks are the cheap ones.
  - `draw`: "Draw a picture with your dots: your face comes apart and all
    your dots crowd into its shape where you are, still your own glowing
    dots in your tone, brighter where the picture is bright. It comes back
    when you clear it or after `seconds`. Use it when a picture says it
    better than words, or when asked to show or draw something. Pass one
    of: `name` = `bank:<id>`, one of these ready pictures: <the ids of
    `content/pixel_garden.json`, read at deploy>, or `today` for today's
    puzzle picture; or `rows` to draw your own: strings of equal length, one
    character a pixel, `.` for empty, any other character a bright pixel;
    an optional `palette` maps a character to a colour whose brightness it
    takes (e.g. a darker outline). Keep your own drawings 8 to 24 pixels a
    side and bold: the shape is what shows. Colour is the tone tool's. `size`
    0.2 to 0.95 of the screen (default 0.7); `seconds` 1 to 60; `clear:
    true` to bring your face back. Your eyes are gone while you draw; move
    still moves the picture." Server checks: one source only; rows 1 to 96
    long and all the same length; palette values a hex or a name from
    `Pal.PG_BEADS`; a `bank:` id in the list. A `png` (base64) source is
    accepted by the phone for a later server-made picture; the model is
    never offered it.
  - `tone` (the user, 2026-11-05: "Give him tool to change particles tone
    and intensity"): "Change the colour and glow of all your dots, your
    face or your drawing: `tone` = green (yours), mint, cyan, blue, violet,
    pink, red, orange, gold, white or #rrggbb; `intensity` 0.2 (dim) to 1
    (as you are) to 1.8 (blazing); either or both. It eases in over a
    second and stays, or flashes for `seconds` and goes back. Fit it to the
    moment or to a drawing (gold for a sun, pink for a heart), and go back
    to green when the moment is over." Server checks: one of the names or a
    6-digit hex; intensity a number (the phone clamps it); seconds 0.5 to
    30.
  - `dots`: "Grow or thin your swarm: `add` or `remove` a number of dots,
    or set a `total`, from 691 to 2400 (you start at 1300). New dots come
    `from` your face (a burst, the default), the `edges` (drifting in) or
    a `point` (x, y 0 to 1); dots go `to` nothing (`fade`, the default),
    into your `face`, or off the `edges`. Only the cloud round you goes,
    never your face; while you draw, new dots join the drawing and dots may
    leave it. More dots let a drawing be more detailed." Server checks: exactly one of add, remove, total, each 1 to
    2400; `from`/`to` in their words.
  - `see` (the user, 2026-11-05: "give the agent a tool to see the screen
    ... in a way that he can draw and see it"): "Look at your own screen:
    you get a picture of it as it is now (only your room: your dots, your
    words). Use it after you draw, to check the drawing reads as what you
    meant; if it does not, change it (simpler rows, bolder shape, another
    tone, more dots) and look again, at most twice. Say nothing about
    looking unless asked." No arguments. This is the one screen tool that
    waits on the phone: the server sends `tool {name: see, id}`, the phone
    answers `{"type": "seen", "id", "jpg", "w", "h"}` (`snapshot(384)` in
    the Swarm tab: the room's last frame, 384 wide, JPEG, about 20 KB) and
    the server gives the model that picture as image input on the turn
    (in Chat Completions a tool message cannot hold an image: the tool
    result says "seen" and a user message with the image follows it). The
    server waits at most 2 s and answers "could not see" past it. The
    picture is not kept: not logged, not in the ledger, not in memory.
    Measured 2026-11-05 (the six demo drawings as `snapshot(384)` gives
    them, "what does the drawing show?"): `gpt-6-luna` takes images but
    misreads them (2 of 6 at high detail, a duck as "a seated person", the
    strawberry as "a skull"; 0 of 2 at low). `gpt-6.1-terra` read 18 of 18
    over three runs in 1.1 to 2.4 s at high detail, 355 tokens in and under
    50 out; `gpt-6.1-sol`, `gpt-6-astra` and `gpt-5.5` 4 or 5 of 6. So the
    call keeps `gpt-6-luna` as the voice and the see tool's picture goes to
    `gpt-6.1-terra` alone, which answers luna in words ("it reads as a
    duck"; "it reads as a cat, not a tulip: thin the leaves, mark the cup"),
    and terra also writes the rows when the agent draws its own. At the
    rates third-party pages quote (terra $1 in / $5 out a million tokens,
    unconfirmed on OpenAI's page) a look is under a tenth of a cent.
  The result the model hears is the phone's own summary when the protocol
  carries one back; until then the server's, from the validated command.
- **Language.** Flux `flux-general-en` for English, `flux-general-multi`
  otherwise; the prompt and the clips in the player's language; ElevenLabs
  v4 turbo is multilingual. The "forget that" and "that's wrong" patterns
  in `memory/turn.py` are English; pt and es patterns are added beside them.
- **Limits.** One call per uid at a time, six calls an hour per uid, a
  call ends itself after fifteen minutes with a line. `max-instances` on
  the service is the bill ceiling (the pattern `submitTurn` documents);
  `concurrency` sized to calls per instance by the first measured
  bot-minute.

### The policy layer *(my call, Flavio may overturn)*

Persona Studio reads every turn with Jev and a small trained network that
decides stance, register, warmth and whether to acknowledge, and learns
corrections per user. For the bot: **the network runs with the base model
and the card's default decision, no per-user delta, and Jev is on only for
English** (the README: the policy was trained on English). Nothing it
learns is written anywhere. If `JEV_API_KEY` is absent the turn uses the
default decision, a path the studio already has. This keeps the demo's
feel for English calls without per-player state on the server.

### Power, screen and sound on the phone

- `core/power.gd` rests the game after twenty seconds without a touch; a
  call has no touches. `BotScreen` holds Power for the call's length the
  way `Music.hold` is held, and keeps the screen on
  (`DisplayServer.screen_set_keep_on(true)`) until the call ends.
- The soundtrack is held (`Music.hold`), as the Swarm tab holds it.
- Going to the background ends the call (the app's `NOTIFICATION_APPLICATION_PAUSED`),
  and the face says goodbye when the player comes back.
- Haptics: a call start, a hang-up and an interruption are each felt
  (`docs/agents/haptics.md`'s kinds); nothing else buzzes.

### Privacy and the store

- Voice goes to Deepgram, OpenAI and ElevenLabs for the call; the game's
  privacy page and the store listings' data-safety sections say so, and
  the microphone purpose strings say what the mic is for.
- The bot sits behind the age gate (`core/age_gate.gd`): the chip is
  hidden until the gate is passed (Flavio, second round).
- Analytics logs `bot_call` with its length in seconds and whether it ended
  by hand, by limit or by error. Never a word said.
- **Owed (Flavio):** whether the ElevenLabs voice `gfRt6Z3Z8aTbpLfexQ7N`
  and the plan's ElevenLabs tier are licensed for a shipped public app;
  the soundtrack's licence review (`docs/agents/sound.md`) is a separate
  question with the same owner.

## Constraints

- Harnesses and the suite never dial out: `Call` is woken only by
  `BotScreen` on a device, and the screen falls back to the `SCRIPT` replay.
- Draw-call budget and the Compatibility renderer as the Swarm tab has
  them; the face is not redrawn.
- Secrets live in Secret Manager and are mounted on the service; nothing
  in the repo or the app. `OPENAI_API_KEY`, `DEEPGRAM_API_KEY`,
  `ELEVENLABS_API_KEY` and `JEV_API_KEY` have to be created in
  `daily-games-420bf`.
- The org policy rejects `allUsers` invokers: making the service public is
  the person-run step `tools/public_invoker.sh` already documents for
  `submitTurn`; the bot gets the same.
- Push to `main` runs CI (tests, APK, Firebase App Distribution). The
  server's deploy is a person-run `gcloud builds submit` until a trigger
  exists; a persona-studio push deploys the demo and is not part of this.

## What is left to the builder

- The exact resampler and frame size on the phone (the spike measures it).
- Whether `clear` on the generator fades at a pause or over 50 ms.
- The memory sheet's look (paper, as the game's sheets are).
- The bot's lines and greeting in the three languages.
- How the subtitles pace without word timings.
- The fork's trimming: which studio modules stay importable.

## Sessions

1. **Spike, the phone's ears.** Godot mic to a loopback socket to the
   speaker on a real Android and iPhone: permissions, `enable_input`,
   frame size at 30 fps, echo on the speaker against earbuds, screen on.
   Exit: full or half duplex decided, with a recording.
2. **The server.** The fork under `server/bot/`, Firebase token auth, the
   DeviceStore with diffs, the peeplet card and its clips, the phone-worded
   tools, pushed events, no persistence, the limits, a priced bot-minute
   from `prices.yaml`, deployed as `peeplet-bot`. Exit: a call from a
   browser test page against the service, memory round-tripping through a
   JSON file.
3. **The client.** `bot/`: the face cut out of the tab, `call.gd`, the
   subtitles, the states, the memory sheet with forget, the permissions,
   Power and screen held. Exit: a call on the phone, a fact remembered the
   next day.
4. **Shipping.** pt and es, the interruption's feel, error states (offline,
   `4401`, `4429`, mid-call drop), analytics, the privacy page and listing
   text, the `docs/agents/bot.md` page, a harness shot of the screen.

Each session commits locally; pushes are Flavio's call.
