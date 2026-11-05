# Peeplet Bot server (fork of Persona Studio)

Forked from `~/dev/hokipoki/persona-studio` at commit **f100de3**
("Reapply seed: Dan's twin thinks on openai:gpt-6-luna ..."). The source repo is
never edited from here.

## What was kept

- `voice/`: the pipecat call (`bot.py`, steer, eager/stop-word turn strategies,
  pace, serializer, clip player, ledger observer, prompt). From `foley.py` only
  the `Listener` backchannel and `strip_tags` remain.
- `policy/`: Jev features, the policy net, behaviours, mood, learner, store.
- `memory/`: `embed`, `gate`, `recall`, `consolidate`, `turn`, and `device`
  (the phone-fed store and hub `turn` runs on, held in RAM for the call).
- `studio/`: `card`, `brains`, `clips`, `prices`, `ledger`, `text_turn`, plus
  `corrections` (imported by the steer; it was not on the brief's list).
- `agent/`: `tools.py` and the `google.py` client it uses.
- `train/common.py` (shared accuracy/decide helpers that `policy.learn` imports,
  minus the pyarrow `load_split`).
- `models/`, `prices.yaml`, `voices.yaml`, `pyproject.toml`, `uv.lock`,
  `.python-version`, `Dockerfile`, `.dockerignore`, and the tests of kept modules.

## What was cut

- Web app and studio: `server.py`, `static/`, `studio/{service,db,desk,voices,compile,calibrate}.py`,
  `seeds/`, `state/`, `data/`, `bench/`, `tools/`, `docs/`, Neon/Cloud Build files.
- Memory storage: `memory/{store,hub,ingest}.py` and `memory/schema/` (Postgres,
  PDF ingest). `memory/device.py` replaces them: the player's facts and
  episodes come in the `hello`, live in RAM, and every change goes back to the
  phone as a `memory` message.
- Room sounds: `RoomTags`, `TagStripper`, the office tag paragraph in the prompt.
- Training: `train/{train_gate,gate_data,gate_rubric}`, the gate data.
- `policy.learn.Learner.install` (needed `studio.calibrate` and pyarrow).
- Dependencies: `psycopg` (re-added on 2026-11-05 for the shared layer, below), `pypdf`, `pyarrow`, dev `datasets`. Added `google-auth`
  and `websockets` (for the test client).
- Tests of every cut module, deleted not skipped. Tests that mixed kept and cut
  code were trimmed (Postgres memory turns, holdout parquet, seeds, room tags).

## Run

```
cd server/bot
uv sync
uv run pytest -q          # no keys, no network
uv run python -c "import voice.bot, memory.turn, agent.tools"
```

## The call (voice/bot.py, voice/phone.py)

After `session`, the socket carries 16-bit PCM both ways and JSON text. Out:
`said {text}` (a sentence as its TTS starts, or a clip's line before it plays),
`state {name}` (listening, thinking, speaking, remembering), `tool {name, cmd}`
(swarm, move, draw, dots, tone; `see` with an `id`), `memory`, `clear`,
`sfx` (the phone drops it), `bye_ack`. In: `interrupt`, `forget {id}`, `bye`,
`seen {id, jpg, w, h}` (waited for 2 s, judged by gpt-6.1-terra in
`agent/eye.py`, never kept). `bye` and the fifteen-minute cap stop the
pipeline, run the memory's `end()` (bounded at 25 s; the OpenAI client
gives up a request at 15 s with one retry), send its `memory` messages and
`bye_ack`, then close 1000. Nothing about a player is written: no policy Store (the
learner is `BaseLearner`, the base only), Jev's cache in RAM, the events log
keeps kinds only, and `server.py` logs at WARNING because Pipecat's DEBUG
lines carry what was said (`bot/logs.py`: no locals in tracebacks, and
Pipecat's raw tool arguments on a parse failure are dropped). The cost
ledger is one per process, in RAM, copied to `BOT_LEDGER` in a worker thread
at each call end (`docs/agents/bot.md`, "Deploy").

`content/pixel_garden.json` is a copy of the game's file, for the draw tool's
bank ids: copy it again when the game's bank changes. The cap's goodbye line
(`goodbye` in each `lines_<lang>`) has its clip in each language since
2026-11-05; a line without a clip is sent as `said` and not heard.

The `Dockerfile` runs `server.py` (`bot.app.build_app`): `GET /health` and the call
socket at `/ws/bot` (`hello` with a Firebase token, then `session`, then the call).
With `BOT_TEST_PAGE=1` it also serves `GET /test` (`static/test.html`), a browser
page to call it from by hand; cost per minute is in `docs/agents/bot.md`.

## The shared layer (shared/)

What every player's Swarm knows in common (spec, "Amendment, 2026-11-05: two layers"):
a Postgres database `swarm` with pgvector on the Neon project `peeplet`, read and
written by the server only (`NEON_SWARM_URL`). `shared/schema.sql` makes the four
tables (`knowledge`, `style`, `turn_outcomes`, `suggestions`); `shared/store.py` is
`SharedStore(dsn)`, which with `dsn=None` reads empty and writes nothing, and with an
unreachable database logs a warning and answers empty. The shared layer embeds with its own multilingual model (`paraphrase-multilingual-MiniLM-L12-v2`, 384 wide; the device memory keeps bge-small), so changing it needs a re-sync. After a database failure the store answers empty for 30 s. Nothing identifying a player
is ever stored. The curated knowledge is `knowledge/<lang>/<topic>.md` (`# Title`,
then one paragraph a row) and goes in with
`uv run python ../../tools/sync_swarm_knowledge.py [--schema]`. Tests that touch the
database run only with `SWARM_TEST_DSN` set (a dev Neon branch, never production).
