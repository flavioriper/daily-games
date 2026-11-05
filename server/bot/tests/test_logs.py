"""The process log keeps no player's words: Pipecat's raw tool arguments are dropped, tracebacks carry no locals."""
import io

from loguru import logger

from bot import logs


def test_pipecat_raw_tool_arguments_are_dropped_and_tracebacks_have_no_locals(monkeypatch):
    monkeypatch.setenv("BOT_LOG_LEVEL", "WARNING")
    out = io.StringIO()
    logs.configure(out)
    try:
        logger.patch(lambda r: r.update(name="pipecat.services.openai.base_llm", function="_process_context")).warning("Failed to parse function call arguments: {'draw': 'Ana'}")
        logger.patch(lambda r: r.update(name="pipecat.services.openai.base_llm", function="process_frame")).warning("kept")

        def boom():
            secret = "Rua Augusta"
            raise RuntimeError(len(secret))  # diagnose=True would print secret's value under this line

        try:
            boom()
        except RuntimeError:
            logger.exception("failed")
    finally:
        logger.remove()
        logger.add(__import__("sys").stderr)
    text = out.getvalue()
    assert "Ana" not in text and "kept" in text and "failed" in text and "Rua Augusta" not in text
