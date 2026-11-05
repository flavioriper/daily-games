"""In-process search over one persona and caller, loaded at call start. Neon is too far for the audio path (about 138 ms a query from this Mac), so a turn never queries it. Vector and keyword rankings merge by reciprocal rank fusion."""
import math
import re
from collections import Counter
from dataclasses import dataclass

import numpy as np

RRF_K = 60
CUTOFF = 0.55  # cosine; set on the made-up contracts
WORD = re.compile(r"[a-z0-9']+")
STOP = set("a about an and any are as at be by can could did do does for from had has have how i if in is it its me my of on or our say says should so tell than that the their them there they this to us was we what when where which who why will with would you your".split())


def tokens(text: str) -> list[str]:
    return [w for w in WORD.findall(text.lower()) if w not in STOP]


def fuse(rankings: list[list[int]], k: int = RRF_K) -> dict[int, float]:
    scores: dict[int, float] = {}
    for ranking in rankings:
        for rank, item in enumerate(ranking, 1):
            scores[item] = scores.get(item, 0.0) + 1 / (k + rank)
    return scores


@dataclass
class Hit:
    text: str
    source: str
    page: int | None
    cosine: float
    rank: int
    kept: bool
    keyword: bool = False

    def as_dict(self) -> dict:
        return dict(self.__dict__)


class Corpus:
    """BM25 and cosine over one list of passages; appending is cheap, so an upload during a call lands at once."""

    def __init__(self):
        self.texts: list[str] = []
        self.meta: list[tuple[str, int | None]] = []
        self.vectors = np.zeros((0, 384), dtype=np.float32)
        self.bags: list[Counter] = []
        self.df: Counter = Counter()

    def add(self, text: str, source: str, page: int | None, embedding) -> None:
        self.texts.append(text)
        self.meta.append((source, page))
        self.vectors = np.vstack([self.vectors, np.asarray(embedding, dtype=np.float32)[None]])
        bag = Counter(tokens(text))
        self.bags.append(bag)
        self.df.update(bag.keys())

    def remove_source(self, source: str) -> None:
        keep = [i for i, m in enumerate(self.meta) if m[0] != source]
        texts, meta, vectors = [self.texts[i] for i in keep], [self.meta[i] for i in keep], self.vectors[keep]
        self.__init__()
        for t, (s, p), v in zip(texts, meta, vectors):
            self.add(t, s, p, v)

    def _bm25(self, query: str, k1: float = 1.5, b: float = 0.75) -> list[int]:
        n = len(self.bags)
        avg = sum(sum(x.values()) for x in self.bags) / max(n, 1)
        scored = []
        for i, bag in enumerate(self.bags):
            length, s = sum(bag.values()), 0.0
            for w in set(tokens(query)):
                if bag[w]:
                    idf = math.log(1 + (n - self.df[w] + 0.5) / (self.df[w] + 0.5))
                    s += idf * bag[w] * (k1 + 1) / (bag[w] + k1 * (1 - b + b * length / avg))
            if s > 0:
                scored.append((s, i))
        return [i for _, i in sorted(scored, reverse=True)]

    def search(self, query: str, embedding, k: int = 3, shown: int = 5, cutoff: float = CUTOFF) -> list[Hit]:
        if not self.texts:
            return []
        cos = self.vectors @ np.asarray(embedding, dtype=np.float32)
        vector_rank = [int(i) for i in np.argsort(-cos)[:20]]
        keyword_rank = self._bm25(query)[:20]
        merged = sorted(fuse([vector_rank, keyword_rank]).items(), key=lambda kv: -kv[1])[:shown]
        hits, kept = [], 0
        for rank, (i, _) in enumerate(merged, 1):
            matched = i in keyword_rank[:3]
            good = kept < k and (float(cos[i]) >= cutoff or matched)
            kept += good
            hits.append(Hit(self.texts[i], *self.meta[i], round(float(cos[i]), 3), rank, good, matched))
        return hits


class RecallIndex:
    def __init__(self):
        self.documents, self.facts, self.episodes = Corpus(), Corpus(), Corpus()
        self.loaded = False
        self.arrivals: list[str] = []  # documents uploaded since the persona last heard about them

    def opening(self, source: str, k: int = 3) -> list[Hit]:
        """The start of a document, for "can you see it?": a question like that shares no words with the file."""
        rows = [i for i, m in enumerate(self.documents.meta) if m[0] == source][:k]
        return [Hit(self.documents.texts[i], source, self.documents.meta[i][1], 1.0, n, True) for n, i in enumerate(rows, 1)]

    def document_names(self) -> list[str]:
        return list(dict.fromkeys(m[0] for m in self.documents.meta))

    @classmethod
    async def load(cls, store, slug: str, user_id: str) -> "RecallIndex":
        index = cls()
        for c in await store.chunks_for(slug):
            index.documents.add(c.text, c.document, c.page, c.embedding)
        for f in await store.facts_for(slug, user_id):
            index.facts.add(f.text, f.id, None, f.embedding)
        for e in await store.episodes_for(slug, user_id):
            index.episodes.add(e.summary, e.created_at[:10], None, e.embedding)
        index.loaded = True
        return index
