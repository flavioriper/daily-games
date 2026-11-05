"""The Swarm's call server: uvicorn on $PORT, GET /health, the call at /ws/bot."""
import os
import sys

import uvicorn
from loguru import logger

from bot.app import build_app

# Pipecat logs what is said at DEBUG ("Generating TTS [...]", transcripts, LLM contexts): on Cloud Run
# stdout is kept, so the call logs warnings and up only and no player's words reach the log.
logger.remove()
logger.add(sys.stderr, level=os.environ.get("BOT_LOG_LEVEL", "WARNING"))

app = build_app()

if __name__ == "__main__":
    uvicorn.run(app, host=os.environ.get("HOST", "0.0.0.0"), port=int(os.environ.get("PORT", "8080")))
