# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""Per (user, persona) state on disk: state/<user_id>/<persona>.pt and an append-only log of accepted corrections."""
import json
import re
from pathlib import Path

from policy.model import Delta

SAFE_ID = re.compile(r"[a-z0-9_-]{1,64}")  # lowercase only: the macOS filesystem would merge "Demo" and "demo"


class Store:
    def __init__(self, root="state"):
        self.root = Path(root)

    def _dir(self, user_id: str, persona: str) -> Path:
        if not SAFE_ID.fullmatch(user_id or ""):
            raise ValueError("user_id must be 1-64 lowercase letters, digits, _ or -")
        if not SAFE_ID.fullmatch(persona or ""):
            raise ValueError(f"unknown persona {persona!r}")
        return self.root / user_id

    def load(self, user_id, persona) -> Delta:
        path = self._dir(user_id, persona) / f"{persona}.pt"
        return Delta.load(path) if path.exists() else Delta.zeros()

    def save(self, user_id, persona, delta: Delta) -> None:
        d = self._dir(user_id, persona)
        d.mkdir(parents=True, exist_ok=True)
        tmp = d / f"{persona}.pt.tmp"
        delta.save(tmp)
        tmp.replace(d / f"{persona}.pt")

    def log(self, user_id, persona, record: dict) -> None:
        d = self._dir(user_id, persona)
        d.mkdir(parents=True, exist_ok=True)
        with open(d / f"{persona}.log.jsonl", "a") as f:
            f.write(json.dumps(record) + "\n")

    def count(self, user_id, persona) -> int:
        path = self._dir(user_id, persona) / f"{persona}.log.jsonl"
        return sum(1 for _ in open(path)) if path.exists() else 0

    def norms(self, user_id, persona, last: int = 20) -> list[float]:
        path = self._dir(user_id, persona) / f"{persona}.log.jsonl"
        return [json.loads(line)["delta_norm"] for line in open(path)][-last:] if path.exists() else []

    def recent(self, user_id, persona, last: int = 5) -> list[dict]:
        """Newest corrections first, without the feature vectors."""
        path = self._dir(user_id, persona) / f"{persona}.log.jsonl"
        rows = [json.loads(line) for line in open(path)][-last:] if path.exists() else []
        return [{k: r.get(k) for k in ("at", "head", "wanted", "delta_norm", "holdout")} for r in reversed(rows)]

    def reset(self, user_id, persona) -> None:
        d = self._dir(user_id, persona)
        for name in (f"{persona}.pt", f"{persona}.log.jsonl"):
            (d / name).unlink(missing_ok=True)
