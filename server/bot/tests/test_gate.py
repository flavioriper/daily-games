import time

import numpy as np
import pytest
import torch

from memory.gate import KEEP, RECALL, GateNet, keep_scores, recall_scores


def test_recall_gives_each_store_a_probability():
    s = recall_scores(GateNet().eval(), torch.zeros(384), torch.zeros(384))
    assert set(s) == set(RECALL) and all(0 <= v <= 1 for v in s.values())


def test_keep_works_when_jev_is_absent():
    s = keep_scores(GateNet().eval(), torch.zeros(384), torch.zeros(384), None)
    assert set(s) == set(KEEP) and sum(s.values()) == pytest.approx(1, abs=0.01)


def test_gate_call_is_inside_budget():
    gate = GateNet().eval()
    t = torch.rand(384)
    recall_scores(gate, t, t)
    started = time.perf_counter()
    for _ in range(50):
        recall_scores(gate, t, t)
    assert (time.perf_counter() - started) / 50 < 0.015

