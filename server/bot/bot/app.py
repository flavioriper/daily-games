"""The call socket: hello, token, limits, a session id, then the call. Nothing about a player is kept here but the uid on a call and call start times."""
import asyncio
import json
import os
import time
import uuid
from collections import deque
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable

from fastapi import FastAPI, WebSocket
from fastapi.responses import FileResponse
from starlette.websockets import WebSocketDisconnect

from bot.auth import Unauthorized, verify
from bot.cards import CLIPS, LANGUAGES, load_card, clip_card
from memory.device import DeviceStore
from studio.clips import has_clips
from voice.phone import Phone

HELLO_SECONDS = 5.0
CALLS_PER_WINDOW = 6
WINDOW_SECONDS = 3600.0

UNAUTHORIZED = 4401  # no or bad token, or this uid is already on a call
RATE_LIMITED = 4429  # six calls in the last hour
NO_CLIPS = 4409  # the language has no pre-made clips
TEST_PAGE = Path(__file__).resolve().parent.parent / "static" / "test.html"


async def wait_for_bye(websocket: WebSocket) -> None:
    """The stand-in call: read until the client says bye or goes away."""
    while True:
        try:
            frame = await websocket.receive()
        except (WebSocketDisconnect, RuntimeError):
            return
        if frame["type"] == "websocket.disconnect":
            return
        text = frame.get("text")
        if text:
            try:
                if json.loads(text).get("type") == "bye":
                    return
            except (ValueError, AttributeError):
                pass


async def stub_run_call(websocket, card, user_id, session_id, deps, store) -> None:
    await wait_for_bye(websocket)


async def voice_run_call(websocket, card, user_id, session_id, deps, store) -> None:
    """The call (voice/bot.py), imported on first use so the socket's tests never load the pipeline."""
    from voice.bot import run_call

    await run_call(websocket, card, user_id, session_id, deps, store)


@dataclass
class Deps:
    """What the app is built with. `run_call` is the seam voice.bot plugs into."""

    run_call: Callable[..., Awaitable[Any]] = voice_run_call  # (websocket, card, user_id, session_id, deps, store)
    verify: Callable[[str], str] = verify
    clips_root: Path = CLIPS  # one folder per language, each with a manifest.json
    now: Callable[[], float] = time.monotonic
    hello_timeout: float = HELLO_SECONDS
    calls_per_window: int = CALLS_PER_WINDOW
    window: float = WINDOW_SECONDS
    # What the call is built with; None takes voice/bot.py's default (keys from the environment)
    services: Callable[..., Any] | None = None  # card -> Services(stt, llm, tts)
    ledger: Any = None
    jev: Callable[[], Any] | None = None  # a fresh Jev per call (English only)
    learner: Any = None
    eye: Any = None
    memory_client: Any = None
    events: Any = None  # a voice.phone.KindLog to keep event kinds; nothing by default
    see_seconds: float = 2.0
    cap_seconds: float = 15 * 60
    shared: Any = None  # the shared layer (shared.store.SharedStore); None builds one from NEON_SWARM_URL, offline when unset


def build_app(deps: Deps | None = None) -> FastAPI:
    deps = deps or Deps()
    if deps.shared is None:
        from shared.store import SharedStore

        deps.shared = SharedStore(os.environ.get("NEON_SWARM_URL"))  # one per process: its pool and its model are shared by every call

    @asynccontextmanager
    async def lifespan(_):
        warming = asyncio.ensure_future(deps.shared.warm()) if getattr(deps.shared, "online", False) else None  # the model loads beside /health and the first call, never in front of them
        try:
            yield
        finally:
            if warming is not None:
                warming.cancel()
            from shared import distil

            await distil.cancel_pending()  # a call's lessons still being distilled are dropped, never queued
            close = getattr(deps.shared, "close", None)
            if close is not None:
                try:
                    await close()
                except Exception:
                    pass  # shutting down anyway

    app = FastAPI(lifespan=lifespan)
    live: set[str] = set()
    starts: dict[str, deque] = {}
    app.state.live = live
    app.state.starts = starts

    @app.get("/health")
    async def health():
        return {"ok": True}

    if os.environ.get("BOT_TEST_PAGE") == "1":  # a local page to call from a browser; never on in production

        @app.get("/test")
        async def test_page():
            return FileResponse(TEST_PAGE, media_type="text/html")

    async def refuse(websocket: WebSocket, code: int) -> None:
        try:
            await websocket.close(code=code)
        except (RuntimeError, WebSocketDisconnect, OSError):  # the client is already gone
            pass

    async def read_hello(websocket: WebSocket) -> dict | None:
        try:
            frame = await asyncio.wait_for(websocket.receive(), deps.hello_timeout)
            raw = frame.get("text")  # a binary or disconnect frame has none
            if raw is None:
                return None
            hello = json.loads(raw)
        except (asyncio.TimeoutError, WebSocketDisconnect, ValueError, RuntimeError, OSError):
            return None
        return hello if isinstance(hello, dict) and hello.get("type") == "hello" else None

    @app.websocket("/ws/bot")
    async def ws_bot(websocket: WebSocket):
        await websocket.accept()
        hello = await read_hello(websocket)
        token = hello.get("token") if hello else None
        if not isinstance(token, str) or not token:
            return await refuse(websocket, UNAUTHORIZED)
        try:
            uid = await asyncio.to_thread(deps.verify, token)
        except Unauthorized:
            return await refuse(websocket, UNAUTHORIZED)
        language = hello.get("language")
        language = language if language in LANGUAGES else "en"
        card = load_card(language)

        # no await between these checks and taking the uid, so two hellos cannot both pass
        if uid in live:
            return await refuse(websocket, UNAUTHORIZED)
        now = deps.now()
        recent = starts.get(uid)
        if recent is not None:
            while recent and now - recent[0] >= deps.window:
                recent.popleft()
            if not recent:
                del starts[uid]
                recent = None
        if recent is not None and len(recent) >= deps.calls_per_window:
            return await refuse(websocket, RATE_LIMITED)
        if not has_clips(clip_card(card), deps.clips_root):  # the clip tools look in <root>/<card.slug>; clip_card makes the slug the language
            return await refuse(websocket, NO_CLIPS)
        live.add(uid)
        starts.setdefault(uid, deque()).append(now)
        try:
            session_id = uuid.uuid4().hex
            await websocket.send_json({"type": "session", "session_id": session_id})
            store = await DeviceStore.load(hello.get("memory") or {}, Phone.of(websocket).send)  # the player's memory, in RAM for this call; every change goes back as `memory`
            await deps.run_call(websocket, card, uid, session_id, deps, store)
        except WebSocketDisconnect:
            pass
        finally:
            live.discard(uid)
            await refuse(websocket, 1000)

    return app
