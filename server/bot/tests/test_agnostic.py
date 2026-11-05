"""Persona Studio names no person in code: every owner-facing string comes from the card."""
import json
import re
import sys
from pathlib import Path

from agent.tools import tool_spec
from studio.card import Card, owner_of, owner_view
from voice.prompt import system_prompt

ROOT = Path(__file__).resolve().parent.parent
# The one place a person's name may stay in code: old /show logs still label a reach step by its old tool name.
ALLOWED = {('agent/tools.py', 'LEGACY_TOOL_NAMES = {"reach_flavio": "reach_owner"}')}
SCANNED = ["agent", "studio", "voice", "memory", "policy"]
SKIP_DIRS = {"__pycache__", "seeds", "tests", "docs", "node_modules", ".venv"}
TEXT = {".py", ".html", ".js", ".css", ".json", ".md", ".txt", ".sql", ".toml"}


def load(path: str, **over) -> Card:
    return Card.model_validate({**json.loads((ROOT / path).read_text()), **over})


def _strip_comment(line: str, suffix: str) -> str:
    """Drops a trailing comment: `#` in Python, `//` in HTML and JS. Good enough for a guard; a `#` or `//` inside a string ends the line early, which can only hide a hit after it."""
    if suffix == ".py":
        return line.split("#", 1)[0]
    if suffix in (".html", ".js"):
        return re.sub(r"(^|[\s;{}()>])//.*$", r"\1", line)
    return line


def grep_repo(pattern: str, include: list[str], skip_comments: bool = False) -> list[str]:
    """`path:line: text` for every line under `include` matching `pattern`, case-insensitive. seeds/, tests/ and docs/ are never scanned."""
    rx, hits = re.compile(pattern, re.I), []
    for top in include:
        base = ROOT / top
        files = [base] if base.is_file() else sorted(p for p in base.rglob("*") if p.is_file())
        for f in files:
            rel = f.relative_to(ROOT).as_posix()
            if SKIP_DIRS & set(Path(rel).parts) or f.suffix not in TEXT:
                continue
            for n, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
                code = _strip_comment(line, f.suffix) if skip_comments else line
                if rx.search(code) and (rel, code.strip()) not in ALLOWED:
                    hits.append(f"{rel}:{n}: {line.strip()}")
    return hits


def test_dana_prompt_and_tools_never_name_flavio():
    card = load("tests/fixtures/persona_dana.json")
    text = system_prompt(card) + json.dumps(tool_spec(owner_of(card))) + owner_view(card).identity
    assert "Flavio" not in text and "Dana" in text


def test_owner_with_no_pronouns_reads_they():
    card = load("tests/fixtures/persona_dana.json", owner={"name": "Sam", "timezone": "UTC"})
    view = owner_view(card).identity.removeprefix(card.identity)  # the fixture's own identity says "she" for Dana; what is checked is what owner_view adds
    assert "Sam" in view and "their calendar" in view
    assert not re.search(r"\b(he|him|his|she|her)\b", view)


def test_no_person_is_hardcoded_in_code():
    hits = grep_repo(r"flavio", include=SCANNED, skip_comments=True)
    assert hits == []
    assert not any(h.startswith(("seeds/", "tests/", "docs/")) for h in grep_repo(r"flavio", include=SCANNED, skip_comments=True))  # the seed is Flavio's own persona and is never scanned (dhh)


def test_the_guard_sees_code_and_skips_comments(tmp_path, monkeypatch):
    (tmp_path / "pkg").mkdir()
    (tmp_path / "pkg" / "a.py").write_text('x = "Flavio"\ny = 1  # Flavio, 2026-11-01\n# Flavio said so\n')
    (tmp_path / "pkg" / "b.html").write_text("<b>the real Flavio</b>\n<script>// Flavio's call\nlet u='http://x/flavio'</script>\n")
    monkeypatch.setattr(sys.modules[__name__], "ROOT", tmp_path)
    hits = grep_repo(r"flavio", include=["pkg"], skip_comments=True)
    assert [h.split(":")[:2] for h in hits] == [["pkg/a.py", "1"], ["pkg/b.html", "1"], ["pkg/b.html", "3"]]


def test_a_template_typo_fails_loudly():
    import pytest
    from studio.card import Owner

    assert Owner(name="Sam").fill("{subject} {goes} and {asks}") == "they go and ask"
    with pytest.raises(KeyError):
        Owner(name="Sam").fill("{possesive}")
