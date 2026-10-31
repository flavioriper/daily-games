# The model labs of 2026-10-30: Gemini and Nova write a day

**Why.** The Anthropic balance hit zero at 00:00 UTC on 2026-10-30 after
US$199 in October, most of it `themeDay` reading Vertex drawings with Opus
5.5 vision every half hour since the picture ports landed on 2026-10-21
(US$11 to 18 a day) plus two local bank days (US$25, US$41). The user has
Google Cloud credits and about US$200 of AWS credits, and ruled Claude on
Bedrock or Vertex out ("claude don't run on aws, check their own models"):
the candidates are Google's Gemini on Vertex AI and Amazon's Nova on
Bedrock. This folder is the record, so the daily flow can be moved later.

**What was built** (commit `45f1f7ff`, local): `ask()` in
`server/functions/src/generate.ts` routes by prefix.

| Prefix | Where | How the schema is held | Notes |
|---|---|---|---|
| `vertex/<model>` (`vertex/gemini-4-argon`, `vertex/gemini-3.8-flash`) | Vertex AI, `VERTEX_PROJECT`, global endpoint, the process's Google identity or `VERTEX_TOKEN_COMMAND` | `responseJsonSchema`; plain JSON with the schema told on a 400 | thinking medium; 90 s a request, three attempts (the global endpoint held one request in four for minutes); 429 waited out 20/40/80 s; thought tokens priced as output |
| `bedrock/<model id>` (`bedrock/global.amazon.nova-2-lite-v1:0`) | Bedrock Converse over REST, `AWS_BEARER_TOKEN_BEDROCK` (a Bedrock API key), `AWS_REGION` | a forced tool `answer` under the schema (constrained decoding); asked again on a malformed answer, then plain JSON | reasoning medium; `maxTokens` 16000; the global profile (the regional one answers 4096 at most) |

`available()` counts a Vertex project or a Bedrock key as a model. `cost()`
prices both (`GEMINI_PRICE`, `NOVA_PRICE`). The theme (`theme.ts`) keeps a
writer's first six things, cuts a `draw` line at the last word before 160,
pins the count in the schema (`minItems`/`maxItems`) and names the rule a
refused answer broke (`whyNotTheme`): Gemini 3.8 Flash gave five, eight and
163 characters where Opus never had.

**The labs.** `run_labs.sh`: day 20261103, one after the other on this Mac,
the same image model on Vertex (`gemini-3-pro-image`, `production-506015`,
token from `gcloud auth print-access-token --account andressa.t@navlio.io`,
the user's pick). `themed`, then `hoops`, `quizzes`, `vistas`. Nova borrowed
Gemini's theme (the `themes-dir` argument). `compare.py` prints the table
from the two day records (`lab-gemini/20261103.json`,
`lab-nova/20261103.json`; the drawings, 40 MB of PNGs, were not kept). The
logs are beside them.

| Day 20261103 | Gemini (Argon reviews and writes rows, 3.8 Flash writes) | Nova 2 Lite everywhere |
|---|---|---|
| Theme | written and passed (morning bakery) | borrowed |
| Pixel pictures kept | 5 sizes (10, 12, 24, 32, 48) in 10 drafts | 2 sizes (12, 24) in 15 drafts |
| Jellies kept | one on every band, 17 tries | one on bands 1 to 3, none on Easy, 21 tries |
| Hoops kept | none, best eye score 6 | two (band 1 cupcake 51 panels, band 2 jam jar 89) |
| Words | made, 3 tries | made, 3 tries |
| Golden Acorn | model on three bands (7/9/9), Insane from the bank on a timeout | model on all four (8/9/9/11) |
| Pearl Dive | all from the bank (the kinds timed out twice) | model on three bands (7/9/9 of 8/9/9) |
| Vistas | four and the header in 5 paintings | none: both mornings refused by its reviewer ("arms too long") |
| Model cost | US$0.86 | US$3.33 |
| Wall time | 2 h 2 min | 1 h 55 min |
| Failures | 23 requests asked again after 90 s; one 429 | 12 answers cut at 16000 tokens (reasoning), 5 malformed tool answers |

Opus did a day's asks for about US$12 to 18.

**What it means.** Gemini's misses were latency, not content: the Pearl
Dive and Acorn Insane fallbacks were timeouts. Nova's misses were content:
on the probes it described a blank icon as a landscape and once said it
"cannot see images" (it did read a real low-poly drawing twice), it kept
fewer pixel sizes, and its reasoning ate the output budget, which is also
why it cost four times more. Its two hoops and its quiz wins carry a caveat:
each lab was judged by its own eye, and Nova's may be kinder than Argon's.

**Confounds.** Each lab drew its own pictures (the `jellies` and `hoops`
commands redraw; `drawingsBeside` only names where the files go), so the
readers saw different drawings; and each lab's reviewer was its own model.
A fairer second round reuses one set of drawings and one judge.

**Recommendation.** Gemini is the viable replacement: Argon on review and
rows, 3.8 Flash on writing, with the step budgets widened or a regional
endpoint to absorb the latency. Nova 2 Lite is fit for the quiz writers
alone (Acorn, Pearl, Shelves, Clues), where the AWS credits would otherwise
sit idle, not as the eye that reads drawings.

## Moving the daily flow (not done)

1. **Models by environment.** `server/functions/.env` (read by every
   function, not secret): `DAILY_MODEL=vertex/gemini-3.8-flash`,
   `DAILY_REVIEW_MODEL=vertex/gemini-4-argon`,
   `DAILY_ROWS_MODEL=vertex/gemini-4-argon`. `VERTEX_PROJECT` is already
   `production-506015`, and the functions' service account already holds
   Vertex AI User there (`tools/vertex_identity.sh`), so Gemini needs no
   secret. For Nova on the quiz writers: a Bedrock API key as the secret
   `AWS_BEARER_TOKEN_BEDROCK` (`firebase functions:secrets:set`), named in
   `secrets:` of `publishDay` and `themeDay` in `index.ts`, and
   `AWS_REGION` in `.env`; `DAILY_MODEL=bedrock/global.amazon.nova-2-lite-v1:0`
   then writes while `DAILY_REVIEW_MODEL` stays on Argon.
2. **Budgets.** Vertex's latency is the risk inside `themeDay`'s thirty
   minutes: `START_BUDGET_MS`, the jelly and hoop step budgets
   (`JELLY_BUDGET_MS`, `HOOP_BUDGET_MS`) and `TRIES` in `themeday.ts` were
   sized for Opus's seconds; read the lab logs' "no answer in 90 s" count
   before deploying. A regional endpoint (`us-central1` in place of
   `global` in `askGemini`) is the other lever.
3. **The day the outage ate.** Steps given up during the outage are marked
   done in the staged theme document (`themes/<day>`, `done` and `tries`):
   clear them for the days still ahead, or those days deal from the banks.
4. **Deploy** by a person: `tools/deploy_functions.sh`. Then read the first
   night's logs (`gcloud logging read ... service_name="themeday"`).
5. **Before trusting Nova anywhere a picture is read**, run the fairer lab:
   one set of drawings, one judge.
