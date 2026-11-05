# The Swarm's call server (`server/bot`)

The live voice call with the Swarm, the friendly companion made of light who
lives in the game: the phone streams the mic over a websocket to
`server/bot` (Deepgram Flux hears, `gpt-6-luna` answers, ElevenLabs speaks,
pre-made clips fill the gaps), and the player's memory travels in the
`hello` and comes back as `memory` messages. How it is built: `server/bot/README.md`.
The one-shot hold-to-talk button that came first is `swarm-talk.md`.

## Testing a call locally

`BOT_TEST_PAGE=1 uv run python server.py` serves `GET /test`
(`server/bot/static/test.html`): paste a Firebase id token, keep or edit the
memory JSON, Call, talk, Bye. `memory` events rewrite the memory box, the
way the phone's file would change. Without `BOT_TEST_PAGE=1` there is no
`/test`. Keys go in the server's environment only: `OPENAI_API_KEY`,
`ELEVENLABS_API_KEY`, `DEEPGRAM_API_KEY`, `JEV_API_KEY`; `BOT_LEDGER=<file>`
keeps the cost rows (RAM otherwise).

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
