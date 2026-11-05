# The Swarm's call server (`server/bot`)

The live voice call with the Swarm, the friendly companion made of light who
lives in the game: the phone streams the mic over a websocket to
`server/bot` (Deepgram Flux hears, `gpt-6-luna` answers, ElevenLabs speaks,
pre-made clips fill the gaps), and the player's memory travels in the
`hello` and comes back as `memory` messages. How it is built: `server/bot/README.md`.
The one-shot hold-to-talk button that came first is `swarm-talk.md`.

## The phone's side

`bot/bot_screen.gd` (the Bot chip, teens and adults only:
`ui/menu/category_row.gd` `entries()`) is the room: the back button, the
log, the status line, the demo pills (offline only), the memory button
(hidden until its sheet). Opening it asks for the mic on Android, takes
`Backend.token()` and dials `bot/call.gd`; no token, a `--script` run or a
refused mic is the offline face (the intro demo, the line after five
seconds). `bot/swarm_face.gd` is the face cut out of the old Swarm tab;
the screen drives it with `set_live`, `set_state`, `set_level`, `say` and
`reveal`, and the `tool` frames with its `apply_*`. A call's `ended` is
counted against the calls the screen let go of, so a late one from a
closed call is ignored; a new call waits for the last one's bye to finish.
`memory` frames are applied whenever they come, after the screen closed
too. Draw calls on the screen offline with the intro talking: 26 (the old
tab with its mic button: 36), 2026-11-05.

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

What the service is: `--max-instances=1 --min-instances=0 --cpu=2
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
