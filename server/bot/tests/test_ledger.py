import pytest

from studio.ledger import Ledger
from studio.prices import Prices

IDS = {"user_id": "u", "persona": "p", "session_id": "s", "source": "test"}


def ledger(tmp_path):
    return Ledger(tmp_path / "l.sqlite", Prices.load("prices.yaml"))


def test_anthropic_net_and_openai_gross_cache_accounting(tmp_path):
    L = ledger(tmp_path)
    a = L.record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 1000, "cache_read_input_tokens": 3000, "completion_tokens": 100, "gross": False}, **IDS)
    assert a.cost_usd == pytest.approx((1000 * 0.10 + 3000 * 0.01 + 100 * 0.50) / 1e6)
    o = L.record(kind="llm", provider="openai", model="gpt-6-luna", units={"prompt_tokens": 4000, "cache_read_input_tokens": 3000, "completion_tokens": 100, "gross": True}, **IDS)
    assert o.cost_usd == pytest.approx(((4000 - 3000) * 0.10 + 3000 * 0.01 + 100 * 0.50) / 1e6)


def test_cache_write_is_billed_at_its_own_rate(tmp_path):
    a = ledger(tmp_path).record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 0, "cache_creation_input_tokens": 1000000, "completion_tokens": 0, "gross": False}, **IDS)
    assert a.cost_usd == pytest.approx(0.125)


def test_unpriced_model_is_none_not_zero(tmp_path):
    r = ledger(tmp_path).record(kind="jev", provider="typesafe", model="jev-unknown", units={"calls": 1}, **IDS)
    assert r.cost_usd is None


def test_jev_calls_are_priced(tmp_path):
    r = ledger(tmp_path).record(kind="jev", provider="typesafe", model="jev-1.13.0", units={"calls": 2}, **IDS)
    assert r.cost_usd == pytest.approx(0.00006)


def test_stt_and_tts_rates(tmp_path):
    L = ledger(tmp_path)
    assert L.record(kind="stt", provider="deepgram", model="flux-general-en", units={"seconds": 60}, **IDS).cost_usd == pytest.approx(0.0078)
    assert L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 1000}, **IDS).cost_usd == pytest.approx(0.04)
    assert L.session_total("s")["total"] == pytest.approx(0.0478)


def test_session_total_flags_unpriced_rows(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="jev", provider="typesafe", model="jev-unknown", units={"calls": 3}, **IDS)
    assert L.session_total("s")["unpriced"] == ["jev"]


def test_projection_uses_measured_mix(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="stt", provider="deepgram", model="flux-general-en", units={"seconds": 600}, **IDS)
    L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 4800}, **IDS)
    per_min = (0.078 + 0.192) / 10
    assert L.projection("u", [10, 30])[1]["monthly_usd"] == pytest.approx(per_min * 30 * 30, rel=0.02)


def test_what_if_reprices_the_same_units(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 1000000, "completion_tokens": 0, "gross": False}, **IDS)
    L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 1000}, **IDS)
    rows = {r["key"]: r for r in L.what_if("s", ["anthropic:claude-sonnet-5-5"], ["inworld:tts-2"])}
    assert rows["anthropic:claude-sonnet-5-5"]["cost_usd"] == pytest.approx(2.0 + 0.04)
    assert rows["inworld:tts-2"]["cost_usd"] == pytest.approx(0.10 + 0.025)


# ---- the bot's one ledger: rows in RAM, copied off the loop -----------------


def test_open_ledger_reads_back_the_copy_and_saves_every_row(tmp_path):
    from studio.ledger import open_ledger

    dest = tmp_path / "bucket" / "ledger.sqlite"
    dest.parent.mkdir()
    L = open_ledger(dest, "prices.yaml")
    L.record(kind="jev", provider="jev", model="jev", units={"calls": 1}, **IDS)
    assert not dest.exists() and L.save() and dest.exists()
    L.close()
    again = open_ledger(dest, "prices.yaml")  # a restart keeps the history it saves over
    again.record(kind="jev", provider="jev", model="jev", units={"calls": 1}, **IDS)
    again.save()
    assert len(Ledger(dest, Prices.load("prices.yaml"))._rows("user_id = ?", "u")) == 2


def test_an_unreadable_copy_is_never_saved_over(tmp_path):
    from studio.ledger import open_ledger

    dest = tmp_path / "ledger.sqlite"
    dest.write_bytes(b"not a database" * 100)
    L = open_ledger(dest, "prices.yaml")
    assert L.dest is None and not L.save() and dest.read_bytes().startswith(b"not a database")


async def test_the_copy_runs_in_a_worker_thread_and_shutdown_saves_and_closes(tmp_path):
    import threading

    from bot.app import close_ledger, save_ledger
    from studio.ledger import open_ledger

    L = open_ledger(tmp_path / "ledger.sqlite", "prices.yaml")
    threads, save = [], L.save
    L.save = lambda *a: (threads.append(threading.get_ident()), save(*a))[1]
    L.record(kind="jev", provider="jev", model="jev", units={"calls": 1}, **IDS)
    task = save_ledger(L)
    assert threads == []  # scheduled, not run on the caller's turn of the loop
    await task
    assert threads and threads[0] != threading.get_ident()
    await close_ledger(L)
    assert len(threads) == 2 and L._closed
    assert save_ledger(open_ledger(None, "prices.yaml")) is None  # nowhere to copy to: nothing scheduled


def test_one_ledger_per_process_shared_by_every_call(monkeypatch):
    from tests.test_auth import hello, make

    monkeypatch.delenv("BOT_LEDGER", raising=False)
    seen = []

    async def run_call(websocket, card, user_id, session_id, deps, store):
        seen.append(deps.ledger)
        from bot.app import wait_for_bye

        await wait_for_bye(websocket)

    client, _ = make(run_call=run_call)
    with client:
        for token in ("good", "other"):
            with client.websocket_connect("/ws/bot") as ws:
                hello(ws, token=token)
                ws.receive_json()
                ws.send_json({"type": "bye"})
    assert len(seen) == 2 and seen[0] is seen[1] and isinstance(seen[0], Ledger)
    assert seen[0]._closed  # closed at shutdown

    from voice.bot import default_ledger

    assert default_ledger() is default_ledger()  # a call run without Deps.ledger reuses one too


def test_prices_are_read_once():
    assert Prices.shared("prices.yaml") is Prices.shared("./prices.yaml")
