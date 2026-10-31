#!/bin/zsh
# Two one-day labs of the night pipeline, run one after the other on this
# Mac: the same day, the same theme (the second borrows the first's), the
# same image model on Vertex; only the writer/reviewer changes.
#   lab-gemini: Gemini 3.8 Flash writes, Gemini 4 Argon reviews and writes rows (Vertex AI, production-506015)
#   lab-nova:   Nova 2 Lite everywhere (Bedrock, the Mac's Bedrock API key)
set -u
DAY=20261103
F=/Users/flavioriper/dev/daily/server/functions
L=/private/tmp/claude-501/-Users-flavioriper-dev-daily/c9862760-28a7-4c2e-8697-3daadd76d36b/scratchpad/labs
export VERTEX_PROJECT=production-506015
export VERTEX_TOKEN_COMMAND="gcloud auth print-access-token --account andressa.t@navlio.io"
export DAILY_PICTURE_STYLE=pixel
export DAILY_IMAGE_MODEL=gemini-3-pro-image
unset ANTHROPIC_API_KEY OPENROUTER_API_KEY
cd $F

run_lab() {
  local name=$1 write=$2 review=$3 rows=$4 lend=$5
  local out=$L/$name log=$L/$name.log
  mkdir -p $out
  export DAILY_MODEL=$write DAILY_REVIEW_MODEL=$review DAILY_ROWS_MODEL=$rows
  echo "=== $name start $(date '+%H:%M:%S') write=$write review=$review rows=$rows" | tee -a $log
  local t0=$(date +%s)
  for step in "themed $DAY 1 $out $lend" "hoops $out/$DAY.json" "quizzes $out/$DAY.json" "vistas $out/$DAY.json"; do
    echo "--- $step $(date '+%H:%M:%S')" | tee -a $log
    node lib/cli.js ${=step} >> $log 2>&1 || echo "--- step failed: $step" | tee -a $log
  done
  echo "=== $name done $(date '+%H:%M:%S'), $(( $(date +%s) - t0 )) s" | tee -a $log
}

run_lab lab-gemini vertex/gemini-3.8-flash vertex/gemini-4-argon vertex/gemini-4-argon ""
run_lab lab-nova bedrock/global.amazon.nova-2-lite-v1:0 bedrock/global.amazon.nova-2-lite-v1:0 bedrock/global.amazon.nova-2-lite-v1:0 $L/lab-gemini
echo "=== both labs done $(date '+%H:%M:%S')" | tee -a $L/run.log
