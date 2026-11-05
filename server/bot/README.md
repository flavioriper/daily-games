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
- Dependencies: `psycopg`, `pypdf`, `pyarrow`, dev `datasets`. Added `google-auth`
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

The `Dockerfile` runs `server.py` (`bot.app.build_app`): `GET /health` and the call
socket at `/ws/bot` (`hello` with a Firebase token, then `session`, then the call).
