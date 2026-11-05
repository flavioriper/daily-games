"""The call's JSON side of the socket. Out: `said`, `state`, `tool`, `memory`, `bye_ack`, in the order they were sent. In: `interrupt`, `forget`, `bye`, and `seen` answering a `tool see`. Nothing here is written anywhere."""
import asyncio
import json
import time
import uuid
from collections import deque
from typing import Awaitable, Callable

from loguru import logger

SEE_SECONDS = 2.0  # how long the see tool waits for the phone's snapshot


class Phone:
    def __init__(self, websocket, see_s: float = SEE_SECONDS):
        self.ws, self.see_s = websocket, see_s
        self.pending: dict[str, asyncio.Future] = {}
        self.open = True
        self.changes = 0  # state changes so far, so a delayed "listening" can tell it was overtaken
        self._queue: deque[dict] = deque()
        self._drain: asyncio.Task | None = None
        self._state: str | None = None
        self.on_interrupt: Callable[[], Awaitable[None]] | None = None
        self.on_forget: Callable[[str], Awaitable[None]] | None = None
        self.on_bye: Callable[[], Awaitable[None]] | None = None

    @classmethod
    def of(cls, websocket, **kw) -> "Phone":
        """One per socket: the socket's memory store and the call share it, so every message keeps its order."""
        phone = getattr(websocket.state, "phone", None)
        if phone is None:
            phone = cls(websocket, **kw)
            websocket.state.phone = phone
        for k, v in kw.items():
            setattr(phone, k, v)
        return phone

    # ---- out -----------------------------------------------------------------

    def send(self, message: dict) -> None:
        """Queued and sent in order by one task, so the loop never waits on the network here."""
        if not self.open:
            return
        self._queue.append(message)
        if self._drain is None or self._drain.done():
            self._drain = asyncio.ensure_future(self._send_all())

    async def _send_all(self) -> None:
        while self._queue:
            message = self._queue.popleft()
            try:
                await self.ws.send_text(json.dumps(message, ensure_ascii=False))
            except Exception as e:  # the phone is gone: what is left has nowhere to go
                logger.debug(f"phone gone: {type(e).__name__}")
                self.open = False
                self._queue.clear()

    async def flush(self) -> None:
        while self._drain is not None and not self._drain.done():
            await asyncio.shield(self._drain)

    def state(self, name: str) -> None:
        if name != self._state:
            self._state = name
            self.changes += 1
            self.send({"type": "state", "name": name})

    def said(self, text: str) -> None:
        if text and text.strip():
            self.send({"type": "said", "text": text.strip()})

    async def look(self) -> dict | None:
        """The see tool's phone half: `tool {name: see, id}`, answered by `seen {id, jpg, w, h}`, or None after see_s."""
        ask_id = uuid.uuid4().hex[:12]
        future = asyncio.get_running_loop().create_future()
        self.pending[ask_id] = future
        try:
            self.send({"type": "tool", "name": "see", "id": ask_id})
            return await asyncio.wait_for(future, self.see_s)
        except asyncio.TimeoutError:
            return None
        finally:
            self.pending.pop(ask_id, None)

    # ---- in ------------------------------------------------------------------

    def on_text(self, raw: str) -> None:
        """Every text frame the transport reads; audio never comes here."""
        try:
            message = json.loads(raw)
        except ValueError:
            return
        if not isinstance(message, dict):
            return
        kind = message.get("type")
        if kind == "seen":
            future = self.pending.get(str(message.get("id")))
            if future is not None and not future.done():
                future.set_result(message)
        elif kind == "interrupt" and self.on_interrupt:
            asyncio.ensure_future(self.on_interrupt())
        elif kind == "forget" and self.on_forget and isinstance(message.get("id"), str) and message["id"]:
            asyncio.ensure_future(self.on_forget(message["id"]))
        elif kind == "bye" and self.on_bye:
            asyncio.ensure_future(self.on_bye())


class KindLog:
    """The bot's events log: the kind of each event and when, never its words, transcripts, memory or pictures."""

    def __init__(self, keep: int = 2000):
        self.items: deque[dict] = deque(maxlen=keep)

    def add(self, event: dict) -> None:
        self.items.append({"t": time.time(), "session_id": event.get("session_id"), "kind": event.get("kind")})


class KeptOpen:
    """The socket as the pipeline sees it: its close is a no-op, so stopping the pipeline on `bye` leaves the socket open for the end of the call's `memory` messages and the `bye_ack`."""

    def __init__(self, websocket):
        self._ws = websocket

    async def close(self, *args, **kwargs) -> None:
        return None

    def __getattr__(self, name):
        return getattr(self._ws, name)
