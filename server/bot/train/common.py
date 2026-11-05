# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""Shared training pieces: the four-head loss, accuracy (with the stop rule, as the page decides) and the majority baseline."""
import torch
from torch import Tensor

from policy.labels import HEADS
from policy.model import STOP_INDEX, STOP_RULE, PolicyNet, forward_with


def loss(outputs: dict[str, Tensor], labels: dict[str, Tensor]) -> Tensor:
    return sum(torch.nn.functional.cross_entropy(outputs[h], labels[h]) for h in HEADS)


def decide(net: PolicyNet, deltas, X: Tensor) -> dict[str, Tensor]:
    """Chosen value index per head for a batch, with the stop rule applied as `predict` applies it."""
    with torch.no_grad():
        out = {h: o.argmax(-1) for h, o in forward_with(net, deltas, X).items()}
    stop = X[:, STOP_INDEX] >= STOP_RULE
    out["stance"] = torch.where(stop, HEADS["stance"].index("hold"), out["stance"])
    out["ack"] = torch.where(stop, HEADS["ack"].index("no"), out["ack"])
    return out


def accuracy(net: PolicyNet, deltas, X: Tensor, Y: dict[str, Tensor]) -> dict[str, float]:
    chosen = decide(net, deltas, X)
    return {h: round(float((chosen[h] == Y[h]).float().mean()), 4) for h in HEADS}


def majority_baseline(Y: dict[str, Tensor]) -> dict[str, float]:
    return {h: round(float(torch.bincount(y).max()) / len(y), 4) for h, y in Y.items()}
