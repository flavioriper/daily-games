import json

import pytest
from starlette.websockets import WebSocketDisconnect
from fastapi.testclient import TestClient

from bot import auth
from bot.app import Deps, build_app, stub_run_call, voice_run_call
from memory.device import DeviceStore
from bot.auth import Unauthorized, verify


def test_verify_rejects_garbage(monkeypatch):
    def no_network(*a, **k):
        raise AssertionError("a malformed token must not dial out")

    monkeypatch.setattr(auth.id_token, "verify_firebase_token", no_network)
    for token in ["x", "", "a.b", "a.b.c.d"]:
        with pytest.raises(Unauthorized):
            verify(token)


def test_verify_returns_uid_and_checks_audience(monkeypatch):
    seen = {}

    def fake(token, request, audience=None, **kw):
        seen.update(audience=audience, **kw)
        return {"sub": "uid-1", "iss": f"https://securetoken.google.com/{audience}"}

    monkeypatch.setattr(auth.id_token, "verify_firebase_token", fake)
    assert verify("a.b.c") == "uid-1"
    assert seen["audience"] == "daily-games-420bf" and seen["clock_skew_in_seconds"] == 10
    assert verify("a.b.c", project="other") == "uid-1" and seen["audience"] == "other"


def test_verify_rejects_a_wrong_issuer(monkeypatch):
    monkeypatch.setattr(auth.id_token, "verify_firebase_token", lambda *a, **k: {"sub": "u", "iss": "https://evil.example/daily-games-420bf"})
    with pytest.raises(Unauthorized):
        verify("a.b.c")


def test_verify_wraps_every_failure(monkeypatch):
    def boom(*a, **k):
        raise ValueError("Token expired")

    monkeypatch.setattr(auth.id_token, "verify_firebase_token", boom)
    with pytest.raises(Unauthorized):
        verify("a.b.c")
    monkeypatch.setattr(auth.id_token, "verify_firebase_token", lambda *a, **k: {})
    with pytest.raises(Unauthorized):
        verify("a.b.c")


def test_certificates_are_fetched_once_per_max_age_with_a_short_timeout():
    import requests

    calls = []

    class Session:
        def request(self, method, url, data=None, headers=None, timeout=None, **kw):
            calls.append(timeout)
            r = requests.Response()
            r.status_code, r._content = 200, b'{"k": "cert"}'
            r.headers["Cache-Control"] = "public, max-age=100, must-revalidate"
            return r

        def close(self):
            pass

    now = [0.0]
    req = auth.CachedRequest(clock=lambda: now[0])
    req.session = Session()
    for _ in range(3):
        assert req("https://certs.example", method="GET").data == b'{"k": "cert"}'
    assert calls == [auth.FETCH_TIMEOUT]  # one fetch, 5 s instead of the library's 120
    now[0] = 101.0
    req("https://certs.example", method="GET")
    assert len(calls) == 2  # past max-age, fetched again
    assert isinstance(auth._request, auth.CachedRequest)


# ---- the socket -------------------------------------------------------------


class Calls:
    """A run_call seam that records its arguments and ends when the client says bye."""

    def __init__(self):
        self.args = []

    async def __call__(self, websocket, card, user_id, session_id, deps, store):
        self.args.append((card, user_id, session_id, store))
        await DEFAULT_WAIT(websocket)


async def _wait(websocket):
    from bot.app import wait_for_bye

    await wait_for_bye(websocket)


DEFAULT_WAIT = _wait


def _verify(token):
    if token not in ("good", "other"):
        raise Unauthorized(token)
    return {"good": "u1", "other": "u2"}[token]


def _clips(languages):
    """A clips folder holding a manifest for each language, as the shipped one does."""
    import tempfile
    from pathlib import Path

    root = Path(tempfile.mkdtemp())
    for language in languages:
        (root / language).mkdir()
        (root / language / "manifest.json").write_text(json.dumps({}))
    return root


def make(**over):
    calls = Calls()
    fields = dict(
        run_call=calls,
        verify=_verify,
        clips_root=_clips(("en", "pt", "es")),
    )
    fields.update(over)
    return TestClient(build_app(Deps(**fields))), calls


def closed_with(ws):
    with pytest.raises(WebSocketDisconnect) as e:
        ws.receive_json()
    return e.value.code


def hello(ws, token="good", language="en", **extra):
    ws.send_json({"type": "hello", "token": token, "language": language, "memory": {"x": 1}, **extra})


def test_health():
    client, _ = make()
    assert client.get("/health").json() == {"ok": True}


def test_hello_without_token_closes_4401():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_json({"type": "hello"})
        assert closed_with(ws) == 4401


def test_not_a_hello_or_not_json_closes_4401():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_json({"type": "audio"})
        assert closed_with(ws) == 4401
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_text("nope")
        assert closed_with(ws) == 4401


def test_bad_token_closes_4401():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws, token="bad")
        assert closed_with(ws) == 4401


def test_silent_client_closes_4401_after_the_deadline():
    client, _ = make(hello_timeout=0.05)
    with client.websocket_connect("/ws/bot") as ws:
        assert closed_with(ws) == 4401


def test_good_hello_gets_a_session_and_the_call_runs_with_the_real_card():
    client, calls = make()
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws, language="pt")
        msg = ws.receive_json()
        assert msg["type"] == "session" and msg["session_id"]
        ws.send_json({"type": "bye"})
    (card, uid, session_id, store), = calls.args
    assert uid == "u1" and session_id == msg["session_id"]
    assert isinstance(store, DeviceStore) and store.facts == [] and store.episodes == []  # the hello's memory had no items
    assert card.language == "pt" and card.slug != "pt"  # the real card, not clip_card's copy


def test_unknown_language_is_english():
    client, calls = make()
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws, language="fr")
        ws.receive_json()
        ws.send_json({"type": "bye"})
    assert calls.args[0][0].language == "en"


def test_no_clips_closes_4409_and_looks_under_the_language_folder():
    client, calls = make(clips_root=_clips(("en",)))  # no es/manifest.json
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws, language="es")
        assert closed_with(ws) == 4409
    assert not calls.args
    with client.websocket_connect("/ws/bot") as ws:  # english is there
        hello(ws, language="en")
        assert ws.receive_json()["type"] == "session"
        ws.send_json({"type": "bye"})
    assert len(calls.args) == 1


def test_a_refused_call_does_not_use_up_the_hourly_allowance():
    client, _ = make(clips_root=_clips(()))
    for _ in range(8):
        with client.websocket_connect("/ws/bot") as ws:
            hello(ws)
            assert closed_with(ws) == 4409


def test_the_shipped_clips_cover_en_pt_es():
    client = TestClient(build_app(Deps(run_call=stub_run_call, verify=_verify)))  # default clips_root
    for language in ("en", "pt", "es"):
        with client.websocket_connect("/ws/bot") as ws:
            hello(ws, language=language)
            assert ws.receive_json()["type"] == "session"
            ws.send_json({"type": "bye"})
        _drain(client)


def test_uid_on_a_call_is_refused_and_freed_when_it_ends():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as first:
        hello(first)
        first.receive_json()
        with client.websocket_connect("/ws/bot") as second:
            hello(second)
            assert closed_with(second) == 4401
        with client.websocket_connect("/ws/bot") as other:  # another player is fine
            hello(other, token="other")
            assert other.receive_json()["type"] == "session"
            other.send_json({"type": "bye"})
        first.send_json({"type": "bye"})
    # the call has ended, so the uid is free again (closing is async: retry a moment)
    for _ in range(50):
        with client.websocket_connect("/ws/bot") as again:
            hello(again)
            try:
                if again.receive_json()["type"] == "session":
                    again.send_json({"type": "bye"})
                    return
            except WebSocketDisconnect:
                pass
    pytest.fail("the uid was never freed")


def test_a_dropped_client_frees_the_uid():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws)
        ws.receive_json()
    # disconnected without bye
    for _ in range(50):
        with client.websocket_connect("/ws/bot") as again:
            hello(again)
            try:
                again.receive_json()
                return
            except WebSocketDisconnect:
                pass
    pytest.fail("the uid was never freed")


def test_hourly_limit_is_six_calls_then_4429_and_the_window_slides():
    now = [0.0]
    client, calls = make(now=lambda: now[0])
    for i in range(6):
        now[0] = i * 10.0
        with client.websocket_connect("/ws/bot") as ws:
            hello(ws)
            assert ws.receive_json()["type"] == "session"
            ws.send_json({"type": "bye"})
        _drain(client)
    now[0] = 100.0
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws)
        assert closed_with(ws) == 4429
    now[0] = 3600.5  # the first call is now older than an hour
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws)
        assert ws.receive_json()["type"] == "session"
        ws.send_json({"type": "bye"})
    assert len(calls.args) == 7


def test_limit_is_per_player():
    now = [0.0]
    client, _ = make(now=lambda: now[0])
    for _ in range(6):
        with client.websocket_connect("/ws/bot") as ws:
            hello(ws)
            ws.receive_json()
            ws.send_json({"type": "bye"})
        _drain(client)
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws, token="other")
        assert ws.receive_json()["type"] == "session"
        ws.send_json({"type": "bye"})


def _drain(client):
    """Wait until u1 is off its call: a fresh connection is not refused as live."""
    import time

    for _ in range(100):
        if "u1" not in client.app.state.live:
            return
        time.sleep(0.01)
    raise AssertionError("u1 stayed live")


def test_the_default_run_call_is_the_voice_call():
    assert Deps().run_call is voice_run_call


def test_default_run_call_stub_ends_on_bye():
    client = TestClient(build_app(Deps(run_call=stub_run_call, verify=_verify, clips_root=_clips(("en",)))))
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws)
        ws.receive_json()
        ws.send_json({"type": "bye"})
        assert closed_with(ws) == 1000


def test_binary_first_frame_closes_4401():
    client, _ = make()
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_bytes(b"\x00\x01")
        assert closed_with(ws) == 4401


def test_a_run_call_that_raises_frees_the_uid():
    async def boom(websocket, card, user_id, session_id, deps, store):
        raise RuntimeError("the call blew up")

    client, _ = make(run_call=boom)
    with pytest.raises(RuntimeError, match="blew up"):  # the test client re-raises what the server logs
        with client.websocket_connect("/ws/bot") as ws:
            hello(ws)
            ws.receive_json()
            ws.receive_json()
    _drain(client)
    assert "u1" not in client.app.state.live


def test_refusals_leave_no_uid_in_the_start_times():
    client, _ = make(clips_root=_clips(()))
    with client.websocket_connect("/ws/bot") as ws:
        hello(ws)
        assert closed_with(ws) == 4409
    assert client.app.state.starts == {}


def test_test_page_only_when_asked(monkeypatch):
    monkeypatch.delenv("BOT_TEST_PAGE", raising=False)
    assert TestClient(build_app(Deps(run_call=stub_run_call))).get("/test").status_code == 404
    monkeypatch.setenv("BOT_TEST_PAGE", "1")
    r = TestClient(build_app(Deps(run_call=stub_run_call))).get("/test")
    assert r.status_code == 200 and "/ws/bot" in r.text and "hello" in r.text
