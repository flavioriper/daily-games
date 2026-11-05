"""The memory path's request detector. The Postgres-backed turn tests went with the hub in the fork."""
from memory.turn import detect_request


def test_requests_are_detected():
    assert detect_request("please don't remember that") == "forget"
    assert detect_request("forget what I said") == "forget"
    assert detect_request("no, that's wrong") == "wrong"
    assert detect_request("do you remember my sister") is None
