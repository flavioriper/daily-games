"""Sentence embeddings, local and in-process, so no network call sits on the audio path. The same model embeds passages and queries."""
import threading

import numpy as np

MODEL = "BAAI/bge-small-en-v1.5"
DIM = 384
_lock = threading.Lock()
_model = None


def _load():
    global _model
    with _lock:
        if _model is None:
            from fastembed import TextEmbedding

            _model = TextEmbedding(MODEL)
    return _model


def embed(texts: list[str]) -> np.ndarray:
    """One normalised row per text; empty text is a zero row, so a turn with no previous line stays well defined."""
    out = np.zeros((len(texts), DIM), dtype=np.float32)
    used = [i for i, t in enumerate(texts) if t.strip()]
    if used:
        out[used] = np.array(list(_load().embed([texts[i] for i in used])), dtype=np.float32)
    return out
