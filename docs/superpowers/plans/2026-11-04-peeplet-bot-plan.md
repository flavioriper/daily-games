# Peeplet Bot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player opens the bot from the first screen, talks to it out loud, hears it answer in the demo's voice, and it remembers them across days with everything it knows kept on the phone.

**Architecture:** A trimmed fork of Persona Studio under `server/bot/` runs one call per socket on Cloud Run (`peeplet-bot`): Flux hears, the steer and OpenAI answer, ElevenLabs speaks, the two screen tools move the face, and a memory store fed by the phone at call start sends back every change as it happens. On the phone, `bot/` holds the screen, the face cut out of today's Swarm tab, one `WebSocketPeer` call with the mic in and the voice out, the subtitles and the memory file.

**Tech Stack:** Python 3.12, Pipecat 1.15 (Deepgram Flux, OpenAI, ElevenLabs Dialogue TTS), FastAPI, torch CPU, fastembed, Cloud Run; Godot 4.7, GDScript, gl_compatibility, `WebSocketPeer`, `AudioStreamMicrophone`, `AudioEffectCapture`, `AudioStreamGenerator`.

**Spec:** `docs/superpowers/specs/2026-11-04-peeplet-bot-design.md`. Persona Studio's source is `~/dev/hokipoki/persona-studio` at commit `f100de3` (record the commit the fork is cut from in `server/bot/README.md`).

## Global Constraints

- The four parts are four sessions; each ends with its exit met, committed locally on `feat/peeplet-bot`. Never push; a push to `main` runs CI, and a push to persona-studio's `main` deploys the demo.
- Nothing about a player persists on the server past the call: no transcripts, no facts, no summaries, no per-user model state. The ledger keeps cost rows keyed by uid only.
- Harnesses and the suite never dial out: `bot/call.gd` is static and woken only by `bot/bot_screen.gd` on a device after `Backend` has an id token. The `SCRIPT` replay stays the offline face.
- Godot: no new suite tests (the user's standing rule). Where a task says "probe", write a throwaway `tests/_probe_<name>.gd` SceneTree script printing PASS/FAIL, run with `godot --headless --path . --script tests/_probe_<name>.gd`. Harnesses one at a time, `--resolution 810x1440` before `--script`, `--always-on-top`, under `caffeinate -d -i -u` and `ulimit -f 2000000`, two readings. `godot --headless --check-only --script <file>` on every edited script.
- Python: the fork keeps the studio's tests that still apply and runs `uv run pytest` without keys or network; one new test per contract named below, nothing more.
- Draw-call budget 855, no `instance uniform`, `--rendering-driver opengl3_angle` once per client task. Honour `Motion.reduce`.
- Text through `locale/ui.csv`; en, pt and es rows together. Titles stay English.
- Audio on the wire: little-endian int16 mono, 16 kHz up, 24 kHz down, as `static/call.js` does. JSON messages are one object per text frame with a `type` field.
- Voice: ElevenLabs `gfRt6Z3Z8aTbpLfexQ7N`, `eleven_v4_turbo`, stability 0.5, delivery tags friendly / cheerful / gentle (the Swarm tab's `tools/gen_swarm_voice.py` settings).
- Limits: one call per uid at a time, six calls an hour per uid, fifteen minutes a call. `max-instances` 1, `min-instances` 0.
- Person-run steps (secrets, service account, public invoker, first deploy) are marked **person-run** and never executed by an agent session.

## Review Focus

1. The mic permission is refused: the screen must show the offline face with a line, never a dead socket (Task 12 probe).
2. The app goes to the background mid-call: the call ends, the mic bus stops capturing, the screen-on hold is released, and the face greets on return (Task 13 probe).
3. The server closes with `4429` or the socket drops mid-call: the face says so in words, the memory file is intact, and the back button still works (Task 15 probe).
4. A `hello` with a corrupt or hand-edited memory file: the server rejects bad items, keeps the rest, and the client never crashes on load (Task 6 test, Task 11 probe).
5. The cold start: a connect that takes forty seconds shows the waking-up face and does not time out before sixty (Task 10 probe).

---

## Part 1: the phone's ears (session 1, the spike)

### Task 1: Microphone and speaker loop on the phone

**Files:**
- Create: `tests/_probe_mic_loop.gd` (throwaway), `tools/bot_echo.py` (throwaway loopback server)
- Modify: `project.godot` (`[audio] driver/enable_input=true`), `export_presets.cfg` (Android `permissions/record_audio=true`; iOS `additional_plist_content` gains `<key>NSMicrophoneUsageDescription</key><string>The bot listens while you talk to it.</string>`)

**Interfaces:**
- Produces: the measured numbers Task 10 needs: mix rate on each phone, capture frames available per process tick at 30 fps, the resampler ratio, whether the speaker's output is heard by the mic (full duplex) or not (half duplex).

- [ ] **Step 1: Write `tools/bot_echo.py`**: a `websockets` server on `0.0.0.0:8765` that echoes every binary frame back after resampling 16 kHz int16 to 24 kHz int16 (linear), and answers a text frame `{"type":"hello"}` with `{"type":"session"}`.
- [ ] **Step 2: Write `tests/_probe_mic_loop.gd`**: a scene that adds a `Mic` bus (volume -80 dB, an `AudioEffectCapture`), an `AudioStreamPlayer` with `AudioStreamMicrophone` on it, an `AudioStreamGenerator` (24 kHz, buffer 0.3 s) on `Master`, connects a `WebSocketPeer` to `ws://<mac-ip>:8765`, sends captured frames resampled to 16 kHz every process tick, pushes received frames to the generator, prints every second: mix rate, frames captured, frames played, round-trip ms. On Android it calls `OS.request_permission("RECORD_AUDIO")` first and prints the `on_request_permissions_result` outcome.
- [ ] **Step 3: Run it on the Mac** against the echo server: `godot --path . --resolution 810x1440 --always-on-top --script res://tests/_probe_mic_loop.gd`. Expected: speech echoed back, round trip under 300 ms.
- [ ] **Step 4: Run it on the Android phone and the iPhone** (debug export, `adb logcat -s godot` / Xcode console). Expected lines printed; on the speaker, say one sentence and note whether the echo is re-captured (a growing loop) or not.
- [ ] **Step 5: Record the numbers** in `docs/agents/bot.md` under "The spike, 2026-xx-xx": mix rates, frames per tick, permission flow, duplex verdict, and whether `AudioServer.input_device` needs choosing on iOS.
- [ ] **Step 6: Commit** `project.godot`, `export_presets.cfg`, `docs/agents/bot.md`; leave the two throwaways untracked.

### Task 2: The duplex decision

- [ ] **Step 1: Decide** from Task 1: full duplex if the mic did not re-capture the speaker on either phone; otherwise half duplex (silence frames while the bot speaks, a tap interrupts). Write the decision and the evidence into the spec under "Duplex" and into `docs/agents/bot.md`.
- [ ] **Step 2: Commit** the spec and the doc.

---

## Part 2: the server (session 2)

### Task 3: The fork

**Files:**
- Create: `server/bot/` from `~/dev/hokipoki/persona-studio` at `f100de3`: keep `voice/` (minus `foley.py` room sounds: keep `strip_tags`), `policy/`, `memory/` (minus `ingest.py`, `store.py`, `hub.py`), `studio/{card,brains,clips,prices,ledger,text_turn}.py`, `agent/tools.py`, `models/`, `prices.yaml`, `voices.yaml`, `pyproject.toml`, `uv.lock`, `.python-version`, `Dockerfile`, `tests/` for kept modules; drop everything else. Create `server/bot/README.md` (source commit, what was cut, how to run).
- Modify: `server/bot/pyproject.toml`: remove `psycopg`, `pypdf`, `pyarrow`; add `google-auth` and `websockets` (for the test client).

- [ ] **Step 1: Copy and cut** as listed; delete imports of dropped modules until `uv run python -c "import voice.bot, memory.turn, agent.tools"` succeeds.
- [ ] **Step 2: Run** `cd server/bot && uv sync && uv run pytest -q`. Expected: the kept tests pass; tests of dropped modules are deleted, not skipped.
- [ ] **Step 3: Commit** `server/bot/` as `feat(bot): fork of persona-studio f100de3, trimmed to a call`.

### Task 4: The peeplet card and its clips

**Files:**
- Create: `server/bot/seeds/peeplet.json`
- Modify: `server/bot/studio/card.py` (nothing structural: confirm `Calibration` accepts the hand-written block)

**Interfaces:**
- Produces: `Card` loaded by `load_card(language: str) -> Card` in `server/bot/bot/cards.py` (new, Task 5 uses it): the seed with `language` set and `lines` taken from `lines_<lang>`.

- [ ] **Step 1: Write the seed**: `slug` `peeplet`, `name` "Peeplet", `identity` per the spec, `style` four lines, `voice` per Global Constraints with `expression.deliveries` `["friendly","cheerful","gentle"]`, `brain` `{"chat":"openai:gpt-6-luna","compile":"openai:gpt-6-luna","memory":"openai:gpt-6-luna"}`, `agent` false, `disclose` true, `room` null, `calibration` `{"delta_norm":0,"slice":{},"accepted":true,"default_decision":{"stance":"execute","register":"standard","warmth":"warm","ack":"no"}}`, and `lines_en`, `lines_pt`, `lines_es` each with greeting, acks, bridges, backchannels, learned, reflexes, thinking, stalls (six each, as `seeds/flavio.json` has).
- [ ] **Step 2: Write `server/bot/bot/cards.py`** with `load_card(language: str) -> Card`.
- [ ] **Step 3: Test** `tests/test_cards.py::test_card_loads_each_language` asserting `load_card(l).lines.greeting` is non-empty for `en`, `pt`, `es` and `card.calibration.accepted`.
- [ ] **Step 4: Render the clips** with `studio/clips.py`'s `render_clips` into `server/bot/voices/peeplet/<lang>/` (spends ElevenLabs credit once; needs `ELEVENLABS_API_KEY` from `~/.config/elevenlabs/api_key`). Expected: `has_clips(card, root)` true for each language.
- [ ] **Step 5: Commit** the seed, `cards.py`, the test and the clips.

### Task 5: Token auth and the socket's envelope

**Files:**
- Create: `server/bot/bot/auth.py`, `server/bot/bot/app.py`, `server/bot/server.py` (replaces the studio's)
- Test: `server/bot/tests/test_auth.py`

**Interfaces:**
- Produces: `verify(token: str, project: str = "daily-games-420bf") -> str` (uid, raises `Unauthorized`); `build_app(deps) -> FastAPI` with `@app.websocket("/ws/bot")` and `@app.get("/health")`; close codes `4401` (no/bad token or uid already on a call), `4429` (hourly limit), `4409` (no clips for the language).
- Consumes: `load_card` (Task 4).

- [ ] **Step 1: Test** `test_verify_rejects_garbage` (`verify("x")` raises) and `test_hello_without_token_closes_4401` (FastAPI `TestClient` websocket, send `{"type":"hello"}`, expect close code 4401).
- [ ] **Step 2: Implement `verify`** with `google.oauth2.id_token.verify_firebase_token` and the project's audience.
- [ ] **Step 3: Implement the socket**: accept; first text frame must be `hello` within five seconds; verify; refuse a uid in `live: set[str]`; count calls per uid in a `deque` of start times, refuse over six in 3600 s; `load_card(language)`; send `{"type":"session","session_id":...}`; call `run_call` (Task 7); on exit remove the uid.
- [ ] **Step 4: Run** `uv run pytest tests/test_auth.py -q`. Expected: PASS.
- [ ] **Step 5: Commit**.

### Task 6: The device-fed memory

**Files:**
- Create: `server/bot/memory/device.py`
- Modify: `server/bot/memory/turn.py` (type hints only; it already talks to `hub` and `hub.store`)
- Test: `server/bot/tests/test_device_memory.py`

**Interfaces:**
- Produces: `DeviceStore(payload: dict, emit: Callable[[dict], None])` with the async methods `memory/turn.py` calls: `facts_for`, `add_fact`, `expire_fact`, `forget_fact`, `add_note`, `notes_for`, `clear_notes`, `clear_stale_notes`, `add_episode`, `episodes_for`, `update_episode`, `log_event` (no-op), `counts`; `DeviceHub(store, models_dir)` with `status="up"`, `ensure()` true, `gate`, `thresholds`, `gate_for()` returning the base gate, `teach_drop()` no-op returning the gate, `attach`/`detach`, `redact` no-op. Every write calls `emit({"type":"memory","op":"add"|"update"|"forget"|"episode","id":str,"text":str})`.
- Memory payload: `{"facts":[{"id","text","since"}],"episodes":[{"id","at","summary"}]}`; items missing `id` or `text`/`summary`, or with text over 300 characters, are dropped on load.

- [ ] **Step 1: Tests**: `test_round_trip` (payload with two facts and one episode: `facts_for` returns two `Fact`s with embeddings; `add_fact` emits `add`; `expire_fact` then `forget_fact` emit `forget`; `add_episode` emits `episode`), `test_bad_items_dropped` (a fact without `text`, one of 400 characters: both dropped, the rest kept).
- [ ] **Step 2: Implement** `DeviceStore` and `DeviceHub`, embedding with `memory.embed.embed` at construction.
- [ ] **Step 3: Run** `uv run pytest tests/test_device_memory.py -q`. Expected: PASS.
- [ ] **Step 4: Commit**.

### Task 7: The call, with pushed events and `bye`

**Files:**
- Modify: `server/bot/voice/bot.py` (`run_call(websocket, card, user_id, session_id, deps, store: DeviceStore)`), `server/bot/agent/tools.py` (phone wording), `server/bot/memory/turn.py` (pt/es `FORGET`/`WRONG` patterns)
- Test: `server/bot/tests/test_call_events.py`

**Interfaces:**
- Produces, on the socket: `said {text}` when a sentence's TTS starts; `state {name: listening|thinking|speaking|remembering}`; `tool {name: swarm|move, cmd}` from the tool result's `swarm`/`move` dict; `memory` (Task 6); `clear`; `bye_ack` then close after `end()`.
- Consumes from the socket: binary audio; `{"type":"interrupt"}` (clears TTS, as a barge-in); `{"type":"forget","id"}` (expires that fact, emits `forget`); `{"type":"bye"}`.
- Tools: `SCREEN` reworded without `cursor`, `input`, `panel:` and the `[screen:` note; `LOOK_WORDS = ["ahead","point",*DIRECTIONS]`, `IDLE = ["ahead","wander","doze"]`, `PLACES` unchanged minus panels.

- [ ] **Step 1: Test** `test_tool_words_have_no_desktop` (no `cursor`, `input`, `panel` in any `SCREEN` description or enum) and `test_forget_patterns_pt_es` (`detect_request("esquece isso")` and `detect_request("olvida eso")` return `"forget"`).
- [ ] **Step 2: Implement**: the events log off (`log` records only `kind`, never `text`); Jev only for `card.language == "en"` (`jev=None` otherwise, so the steer takes the card's default decision); no per-user learner deltas (`learner.user_delta` reads the base, writes nothing); `said` sent from the `said` handler before the clip plays; `state` from the steer's stage events; `tool` from `act`; `bye` handled in the transport's text-frame handler: cancel the task, `await memory.end(messages)`, send `bye_ack`, close `1000`; the fifteen-minute cap sends `said` with the card's goodbye line then `bye` itself.
- [ ] **Step 3: Run** `uv run pytest -q`. Expected: PASS.
- [ ] **Step 4: Commit**.

### Task 8: A browser test page and a priced minute

**Files:**
- Create: `server/bot/static/test.html` (the studio's `call.js` with a token box and a memory textarea; `hello` sends both; events print to a log; `bye` on a button)
- Modify: `server/bot/server.py` (`GET /test` only when `BOT_TEST_PAGE=1`)

- [ ] **Step 1: Run locally** with keys from `~/.config/{openai,elevenlabs}/api_key` and `DEEPGRAM_API_KEY` in the environment: `uv run python server.py`; open `/test`, paste an id token (from `tools/_backend_probe.gd` or the Firebase emulator's), talk for two minutes, say "remember that I like chess", hang up, confirm `memory` events land in the textarea and the ledger shows the call.
- [ ] **Step 2: Price it**: `uv run python -c "..."` summing the ledger's session rows with `prices.yaml`; write the cost of that call per minute into `docs/agents/bot.md`.
- [ ] **Step 3: Commit** the page and the doc line.

### Task 9: Deploy `peeplet-bot` *(person-run steps marked)*

**Files:**
- Create: `server/bot/cloudbuild.yaml` (from the studio's: service `peeplet-bot`, `--max-instances=1 --min-instances=0 --cpu=2 --memory=2Gi --no-cpu-throttling --timeout=3600 --concurrency=<measured>`, volume `STUDIO_DATA` on bucket `daily-games-420bf-peeplet-bot`, secrets `OPENAI_API_KEY`, `DEEPGRAM_API_KEY`, `ELEVENLABS_API_KEY`, `JEV_API_KEY`), `tools/deploy_bot.sh` (person-run `gcloud builds submit`), `docs/agents/bot.md` section "Deploy"
- Modify: `server/bot/Dockerfile` (bake `voices/peeplet`, `FASTEMBED_CACHE_PATH`)

- [ ] **Step 1: Write** the three files; `docs/agents/bot.md` lists, in order, the **person-run** steps: settle the admin account (`gcloud auth login` as the project's owner; the navlio account was denied on 2026-11-04, the firebase CLI deploys as `flavio@hypertradeworx.xyz`), create the four secrets, the bucket, the `peeplet-bot` service account with `roles/storage.objectAdmin` on the bucket and `secretmanager.secretAccessor` on its secrets, `tools/deploy_bot.sh`, then `tools/public_invoker.sh peeplet-bot`.
- [ ] **Step 2: Hand the steps to Flavio** and wait; the session does not run them.
- [ ] **Step 3: After the deploy**, `curl https://<service-url>/health` expected `{"ok":true}`; the test page from Task 8 against the service: a call works, memory round-trips.
- [ ] **Step 4: Measure concurrency**: two test pages at once; note CPU in Cloud Run metrics; set `--concurrency` and record it in the doc.
- [ ] **Step 5: Commit**.

---

## Part 3: the client (session 3)

### Task 10: `bot/call.gd`

**Files:**
- Create: `bot/call.gd`
- Modify: `ui/menu/swarm_tab.gd:` the `Swarm` bus creation moves to `call.gd` (`_ensure_bus`) so both share it

**Interfaces:**
- Produces: `class_name BotCall` static: `start(host: Node, url: String, token: String, memory: Dictionary, language: String) -> void`, `stop() -> void` (sends `bye`, waits for `bye_ack` or six seconds), `interrupt() -> void`, `forget(id: String) -> void`, `send_silence(on: bool) -> void` (half duplex), `level() -> float` (the Swarm bus analyser, 0..1), signals `event(msg: Dictionary)` (every JSON frame), `ended(reason: String)` (`"bye"`, `"4401"`, `"4429"`, `"4409"`, `"dropped"`, `"timeout"`). Connect timeout sixty seconds; the URL from `Backend`-style constants `BOT_URL`; the token from `Backend.token()` (`core/backend.gd:88`, empty when unstarted, which is the offline case).
- Audio: mic frames resampled with the ratio from Task 1, sent as ~20 ms int16 frames; incoming frames into an `AudioStreamGenerator` 24 kHz on the `Swarm` bus; `clear` drops the queue after a 50 ms fade.

- [ ] **Step 1: Probe** `tests/_probe_bot_call.gd` against `tools/bot_echo.py` (Task 1): `start` with a dummy token; expect `event` with `type == "session"` within two seconds, echoed audio playing, `stop()` emits `ended("bye")` within six seconds even without `bye_ack`; a server that never answers emits `ended("timeout")` at sixty seconds (test with the echo server paused).
- [ ] **Step 2: Implement** `bot/call.gd`.
- [ ] **Step 3: Run** the probe. Expected: PASS lines for each.
- [ ] **Step 4: Commit**.

### Task 11: `bot/bot_memory.gd`

**Files:**
- Create: `bot/bot_memory.gd`

**Interfaces:**
- Produces: `class_name BotMemory` static: `path` (`user://bot_memory.json`), `load() -> Dictionary` (`{"facts":[], "episodes":[]}` on a missing or corrupt file; drops items without `id` and `text`/`summary`), `apply(msg: Dictionary) -> void` (`add`, `update`, `forget`, `episode`; saves at once), `forget(id: String) -> void`, `payload() -> Dictionary` (what `hello` sends), `clear() -> void`.

- [ ] **Step 1: Probe** `tests/_probe_bot_memory.gd`: point `path` at `user://_probe_bot_memory.json`; `apply` an add, an update, an episode, a forget; reload; expect one fact with the updated text and one episode; write garbage to the file; `load()` returns the empty shape; delete the file on every exit path.
- [ ] **Step 2: Implement**.
- [ ] **Step 3: Run** the probe. Expected: PASS.
- [ ] **Step 4: Commit**.

### Task 12: The face cut out of the tab

**Files:**
- Create: `bot/swarm_face.gd` (from `ui/menu/swarm_tab.gd`: the sim, the shaders' nodes, the bloom, `apply_swarm`, `apply_move`, `set_state(name)`, `set_level(v)`, `say(text)` for the subtitles, the `SCRIPT` replay as `play_demo()`), `bot/bot_screen.gd` (the room, the back button, the log, the memory sheet button, the permission ask, Power and Music holds, the offline fallback)
- Modify: `ui/menu.gd:1231-1250` (`"bot"` opens `BotScreen`), `ui/menu/category_row.gd:45` (key `bot`, label `BAR_BOT`, hidden unless `AgeGate.band() >= AgeGate.TEEN`), `locale/ui.csv` (`BAR_BOT`, `BOT_MIC_REFUSED`, `BOT_OFFLINE`, `BOT_WAKING`, `BOT_REMEMBERING`, `BOT_LIMIT`, `BOT_DROPPED`, `BOT_KNOWN_TITLE`, `BOT_KNOWN_NONE`, `BOT_FORGET` in en, pt, es), `tests/_shot_menu.gd` (`swarm` arg becomes `bot`, opens the screen in demo mode)
- Delete: `ui/menu/swarm_tab.gd`

**Interfaces:**
- Consumes: `BotCall` (Task 10), `BotMemory` (Task 11).
- Produces: `BotScreen.open()`, `close()`, `is_open()`, signal `closed`; `SwarmFace` as above.

- [ ] **Step 1: Move** the code; `godot --headless --check-only` on both scripts (expect the `Ads` autoload stop as today; the harness is the real check).
- [ ] **Step 2: Wire** the states: connecting → `BOT_WAKING` over the demo face until `session`; `session` → listening; `state` events → `set_state`; `said` → `say`, which reveals the sentence's characters in proportion to audio frames the generator has consumed since the event against the sentence's length at 16 characters a second; `tool` → `apply_swarm`/`apply_move`; a tap on the face → `BotCall.interrupt()` (and `send_silence(false)` under half duplex); `memory` → `BotMemory.apply`; `ended` → a line by reason and the offline face; the permission refusal → `BOT_MIC_REFUSED` over the demo face.
- [ ] **Step 3: Probe** `tests/_probe_bot_screen.gd`: open the screen with `BotCall` unstarted (offline): expect the demo playing and `BOT_OFFLINE` shown after five seconds; a fake `ended("4429")` shows `BOT_LIMIT`; `AgeGate` child band hides the chip (`category_row` entries exclude `bot`).
- [ ] **Step 4: Harness** `tests/_shot_menu.gd -- bot` on both drivers; expect the face as before and draw calls at or under 21 on the tab.
- [ ] **Step 5: Commit**.

### Task 13: Power, screen, background and haptics

**Files:**
- Modify: `bot/bot_screen.gd`, `core/power.gd` (a `hold(who, on)` like `Music.hold` if none exists; verify first)

- [ ] **Step 1: Implement**: `Power.hold("bot", true)` and `DisplayServer.screen_set_keep_on(true)` from `open()` until the call ends; `NOTIFICATION_APPLICATION_PAUSED` ends the call (`BotCall.stop()` with no wait); on resume the face says the greeting line again via `say`; `Haptics` on start, hang-up and interrupt per `docs/agents/haptics.md`.
- [ ] **Step 2: Probe** `tests/_probe_bot_power.gd`: open the screen, advance thirty seconds of fake idle, expect `Power` not rested; send the pause notification, expect `ended` and the keep-on released.
- [ ] **Step 3: Commit**.

### Task 14: The memory sheet

**Files:**
- Create: `bot/memory_sheet.gd` (a paper sheet in the house style, `docs/agents/art-and-ui.md`: title `BOT_KNOWN_TITLE`, a chip per fact and a row per episode, a tap on a chip asks `BOT_FORGET` and forgets through `BotMemory.forget` and, during a call, `BotCall.forget`)

- [ ] **Step 1: Implement** on the sheet precedent named in `docs/agents/art-and-ui.md`.
- [ ] **Step 2: Harness** shot of the sheet open (`_shot_menu.gd -- bot sheet`), one reading each driver.
- [ ] **Step 3: Commit**.

### Task 15: The first real call

- [ ] **Step 1: On the phone**, debug build, open the bot, talk for a minute, say something to remember, hang up, kill the app, reopen the next day (or move the clock) and ask what it remembers. Expected: it does.
- [ ] **Step 2: Break it**: airplane mode mid-call (expect `BOT_DROPPED`, memory file intact, back works); start a second call from another phone with the same uid (expect `4401` line).
- [ ] **Step 3: Record** what was seen in `docs/agents/bot.md`; commit.

---

## Part 4: shipping (session 4)

### Task 16: Portuguese and Spanish

- [ ] **Step 1: Run** a call in pt and one in es on the phone (switch the game's locale in Settings). Expected: Flux `flux-general-multi` transcribes, the clips and the greeting are in that language, the subtitles too.
- [ ] **Step 2: Fix** what fails; commit.

### Task 17: Interruption and silence

- [ ] **Step 1: Tune** by ear: barge-in (full duplex) or the tap (half duplex) stops the voice within 200 ms; a long quiet makes the face `doze` through its own `idle` tool, never a prompt.
- [ ] **Step 2: Commit**.

### Task 18: Analytics, privacy, listings

**Files:**
- Modify: `core/analytics.gd` (event `bot_call` with `seconds` and `end` reason, per `docs/agents/analytics.md`), `web/` privacy page (voice sent to Deepgram, OpenAI, ElevenLabs for the call; nothing kept on a server; memory on the device), store data-safety notes in `docs/agents/android.md` and the iOS listing notes (the user sends them)

- [ ] **Step 1: Implement** the event; write the privacy paragraph and the listing text.
- [ ] **Step 2: Commit**.

### Task 19: The docs page and the handoff

- [ ] **Step 1: Write** `docs/agents/bot.md` as the area's page (the table in `CLAUDE.md` gains a row): the pieces, the protocol, the limits, the deploy steps, what is owed.
- [ ] **Step 2: Update** `CLAUDE.md`'s table and the memory note; commit.
- [ ] **Step 3: Hand over**: the branch is Flavio's to merge and push; the server deploys by `tools/deploy_bot.sh` (person-run).
