"""Throwaway echo stand-in for the call server (Task 10 probe). 127.0.0.1:8765.
Paths pick the mode: /normal (session, echo 16k->24k, bye_ack), /noack (never answers bye),
/paused (accepts, never sends session), /refuse4429 (closes 4429 after hello), /eagerclose (memory + bye_ack back to back, then the fixed server's wait for the phone's close), /oldclose (closes right behind bye_ack, the server before fix round 1), /remember (remembering + 4 memory frames 4 s apart, then bye_ack), /forever (memory every 4 s, never bye_ack). Port 8766 accepts TCP and never answers the upgrade.
Run: cd server/bot && uv run python ../../tools/bot_echo.py"""
import asyncio
import json
from array import array

from websockets.asyncio.server import serve


def up16_to_24(raw: bytes) -> bytes:
    src = array("h")
    src.frombytes(raw[: len(raw) // 2 * 2])
    n = len(src)
    if n == 0:
        return b""
    out = array("h", [0]) * (n * 3 // 2)
    for i in range(len(out)):
        x = i * 2 / 3
        a = int(x)
        b = min(a + 1, n - 1)
        f = x - a
        out[i] = int(src[a] * (1 - f) + src[b] * f)
    return out.tobytes()


async def handler(ws):
    mode = ws.request.path.strip("/").split("/")[-1] or "normal"
    print("conn", mode, flush=True)
    async for msg in ws:
        if isinstance(msg, bytes):
            if mode != "paused":
                await ws.send(up16_to_24(msg))
            continue
        m = json.loads(msg)
        t = m.get("type")
        print("<", t, flush=True)
        if t == "hello":
            if mode == "paused":
                continue
            if mode == "refuse4429":
                await ws.close(4429)
                return
            await ws.send(json.dumps({"type": "session", "session_id": "echo"}))
            await ws.send(json.dumps({"type": "state", "name": "listening"}))
        elif t == "bye":
            if mode == "noack":
                continue
            if mode in ("remember", "forever"):  # a slow end-of-call memory, as the real server's remembering
                await ws.send(json.dumps({"type": "state", "name": "remembering"}))
                k = 0
                while mode == "forever" or k < 4:
                    if k:
                        await asyncio.sleep(4.0)
                    await ws.send(json.dumps({"type": "memory", "op": "add", "id": f"f{k}", "text": f"fact {k}"}))
                    k += 1
            await ws.send(json.dumps({"type": "memory", "op": "episode", "id": "e1", "text": "echoed"}))
            await ws.send(json.dumps({"type": "bye_ack"}))
            if mode != "oldclose":  # the fixed server: the phone closes first, up to 2 s
                try:
                    await asyncio.wait_for(ws.wait_closed(), 2.0)
                except asyncio.TimeoutError:
                    pass
            await ws.close(1000)
            return
        elif t == "interrupt":
            await ws.send(json.dumps({"type": "clear"}))


async def mute(reader, writer):
    """Port 8766: takes the TCP connection and never answers the upgrade (a server still waking)."""
    print("mute conn", flush=True)
    await reader.read()  # until the client gives up


async def main():
    mute_server = await asyncio.start_server(mute, "127.0.0.1", 8766)
    async with serve(handler, "127.0.0.1", 8765, max_size=None), mute_server:
        await asyncio.Future()


asyncio.run(main())
