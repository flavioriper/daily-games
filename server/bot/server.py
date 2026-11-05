"""The Swarm's call server: uvicorn on $PORT, GET /health, the call at /ws/bot."""
import os

import uvicorn

from bot.app import build_app
from bot.logs import configure

configure()  # warnings and up, no locals in tracebacks, Pipecat's raw tool arguments dropped (bot/logs.py)

app = build_app()

if __name__ == "__main__":
    uvicorn.run(app, host=os.environ.get("HOST", "0.0.0.0"), port=int(os.environ.get("PORT", "8080")))
