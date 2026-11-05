"""The process's log: warnings and up on stderr, nothing a player said in it."""
import os
import sys

from loguru import logger

# Records Pipecat writes with what was said in them, dropped whatever the level: matched by where they come from, never
# by their text. OpenAI's _process_context logs only one thing, a tool call's raw arguments when they fail to parse.
QUIET = {("pipecat.services.openai.base_llm", "_process_context")}


def keep(record) -> bool:
    return (record["name"], record["function"]) not in QUIET


def configure(sink=sys.stderr) -> int:
    """Pipecat logs what is said at DEBUG ("Generating TTS [...]", transcripts, LLM contexts): on Cloud Run stdout is
    kept, so the call logs warnings and up only. diagnose and backtrace are off: loguru's defaults print every frame's
    locals (a transcript, a token) into a traceback."""
    logger.remove()
    return logger.add(sink, level=os.environ.get("BOT_LOG_LEVEL", "WARNING"), filter=keep, backtrace=False, diagnose=False)
