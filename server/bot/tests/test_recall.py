import numpy as np
import pytest

from memory.embed import embed
from memory.recall import Corpus, RecallIndex, fuse


def test_fusion_matches_the_formula():
    s = fuse([[1, 2], [2, 3]])
    assert s[2] == pytest.approx(1 / 62 + 1 / 61)
    assert s[1] == pytest.approx(1 / 61)
    assert s[3] == pytest.approx(1 / 62)


def corpus(lines):
    c = Corpus()
    for line, v in zip(lines, embed(lines)):
        c.add(line, "msa.md", 1, v)
    return c


def test_exact_contract_term_beats_a_vague_neighbour():
    c = corpus(["The parties agree to be nice to each other in general.", "Indemnification: each party shall hold the other harmless against claims.", "Payment is due in thirty days."])
    q = "what about indemnification"
    assert "Indemnification" in c.search(q, embed([q])[0])[0].text


def test_weak_hits_are_shown_but_not_kept():
    c = corpus(["The quick brown fox jumps over the lazy dog."])
    q = "termination for convenience"
    hit = c.search(q, embed([q])[0])[0]
    assert not hit.kept


def test_empty_index_finds_nothing():
    assert RecallIndex().documents.search("x", np.zeros(384)) == []


def test_removing_a_source_removes_its_passages():
    c = corpus(["a contract line"])
    c.add("other", "b.md", 2, embed(["other"])[0])
    c.remove_source("msa.md")
    assert c.texts == ["other"] and c.vectors.shape == (1, 384)
