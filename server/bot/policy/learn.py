# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""Live learning from one user's corrections, under guards (spec 4.3).

Each correction is one clipped SGD step on that user's delta only, and only on the output rows of the head being corrected: a step through the
shared hidden layer bleeds into every head, and on real-shaped data it spent the stance budget in two corrections (review C1). The candidate is refused when it would teach a stop turn, drop the persona's
held-out `stance` accuracy more than TOLERANCE below its calibrated value, or stop holding on a slice row the calibrated persona holds on.
`register`, `warmth` and `ack` are the user's to move: their accuracies are reported, never enforced.
"""
import threading
import time
from dataclasses import dataclass

import torch
from torch import Tensor

from policy.labels import HEADS
from policy.model import STOP_INDEX, STOP_RULE, Delta, PolicyNet, forward_with
from policy.store import Store
from train.common import accuracy, decide

LR = 0.08
L2 = 0.1
CLIP = 0.5
TOLERANCE = 0.02
STOP = STOP_RULE
HOLD = HEADS["stance"].index("hold")
OUTPUT = ("net.2.weight", "net.2.bias")


def head_rows(head: str) -> slice:
    start = sum(len(v) for h, v in HEADS.items() if list(HEADS).index(h) < list(HEADS).index(head))
    return slice(start, start + len(HEADS[head]))


@dataclass
class Correction:
    user_id: str
    persona: str
    features: list[float]
    head: str
    wanted: str


@dataclass
class Outcome:
    accepted: bool
    reason: str
    delta_norm: float
    holdout: dict[str, float]


class Learner:
    def __init__(self, base: PolicyNet, persona_deltas: dict[str, Delta], slices: dict[str, tuple[Tensor, dict]], calibrated: dict[str, dict[str, float]], store: Store):
        self.base, self.persona_deltas, self.slices, self.calibrated, self.store = base, persona_deltas, slices, calibrated, store
        self._deltas: dict[tuple[str, str], Delta] = {}
        self._locks: dict[tuple[str, str], threading.Lock] = {}
        self._locks_guard = threading.Lock()
        self._held = {}
        for p in slices:
            self._mark_held(p)

    def _mark_held(self, p) -> None:
        # the slice rows the calibrated persona (no user delta) holds on: the ones a user must never talk it out of
        X, Y = self.slices[p]
        chosen = decide(self.base, [self.persona_deltas[p]], X)["stance"]
        self._held[p] = (Y["stance"] == HOLD) & (chosen == HOLD)

    def _lock(self, key) -> threading.Lock:
        with self._locks_guard:
            return self._locks.setdefault(key, threading.Lock())

    def user_delta(self, user_id, persona) -> Delta:
        key = (user_id, persona)
        if key not in self._deltas:
            self._deltas[key] = self.store.load(user_id, persona)
        return self._deltas[key]

    def deltas_for(self, user_id, persona) -> list[Delta]:
        return [self.persona_deltas[persona], self.user_delta(user_id, persona)]

    def _holdout(self, persona, user: Delta) -> dict[str, float]:
        return accuracy(self.base, [self.persona_deltas[persona], user], *self.slices[persona])

    def correct(self, c: Correction) -> Outcome:
        if c.head not in HEADS or c.wanted not in HEADS[c.head]:
            raise ValueError(f"{c.head}={c.wanted} is not a value of the policy")
        with self._lock((c.user_id, c.persona)):
            current = self.user_delta(c.user_id, c.persona)
            if c.features[STOP_INDEX] >= STOP:
                return Outcome(False, "stop turns are not learnable", current.norm(), {})

            candidate = current.clone()
            params = [candidate.tensors[k].requires_grad_() for k in OUTPUT]
            x = torch.tensor(c.features, dtype=torch.float32)
            logits = forward_with(self.base, [self.persona_deltas[c.persona], candidate], x)[c.head]
            target = torch.tensor(HEADS[c.head].index(c.wanted))
            l = torch.nn.functional.cross_entropy(logits.unsqueeze(0), target.unsqueeze(0)) + L2 * sum((p**2).sum() for p in params)
            grads = torch.autograd.grad(l, params)
            rows = head_rows(c.head)
            step = []
            for g in grads:
                masked = torch.zeros_like(g)
                masked[rows] = g[rows]
                step.append(-LR * masked)
            size = float(torch.sqrt(sum((s**2).sum() for s in step)))
            scale = min(1.0, CLIP / size) if size > 0 else 1.0
            tensors = {k: t.detach() for k, t in candidate.tensors.items()}
            for k, s in zip(OUTPUT, step):
                tensors[k] = tensors[k] + s * scale
            candidate = Delta(tensors)

            holdout = self._holdout(c.persona, candidate)
            X, _ = self.slices[c.persona]
            if holdout["stance"] < self.calibrated[c.persona]["stance"] - TOLERANCE:
                return Outcome(False, "would regress held-out stance", current.norm(), holdout)
            chosen = decide(self.base, [self.persona_deltas[c.persona], candidate], X)["stance"]
            if bool((self._held[c.persona] & (chosen != HOLD)).any()):
                return Outcome(False, "would stop holding on a hold turn", current.norm(), holdout)

            self._deltas[(c.user_id, c.persona)] = candidate
            self.store.save(c.user_id, c.persona, candidate)
            norm = candidate.norm()
            self.store.log(c.user_id, c.persona, {"at": time.time(), "head": c.head, "wanted": c.wanted, "features": c.features, "delta_norm": norm, "holdout": holdout})
            return Outcome(True, "accepted", norm, holdout)

    def reset(self, user_id, persona) -> Outcome:
        with self._lock((user_id, persona)):
            self.store.reset(user_id, persona)
            self._deltas[(user_id, persona)] = Delta.zeros()
            return Outcome(True, "reset", 0.0, self._holdout(persona, Delta.zeros()))


class BaseLearner:
    """The bot's policy: the shipped base net, no persona or player delta, nothing learned and nothing written. A player's corrections would be data about them kept on the server, so there is no Store here at all."""

    def __init__(self, base: PolicyNet):
        self.base, self.store = base, None
        self._zero = Delta.zeros()
        self.persona_deltas: dict[str, Delta] = {}

    def user_delta(self, user_id, persona) -> Delta:
        return self._zero

    def deltas_for(self, user_id, persona) -> list[Delta]:
        return [self._zero]

    def correct(self, c: Correction) -> Outcome:
        return Outcome(False, "not kept on the server", 0.0, {})


def load_base(path) -> PolicyNet:
    net = PolicyNet()
    net.load_state_dict(torch.load(path, weights_only=True))
    net.requires_grad_(False)
    return net
