"""The memory gate: one small hidden layer, two heads. Recall reads what was said and the line before it, so it can start without waiting for Jev. Keep runs after the turn and also reads Jev's 21 signals."""
import torch
from torch import Tensor, nn

from memory.embed import DIM as EMBED
from policy.features import DIM as SIGNALS

RECALL = ("facts", "episodes", "documents")
KEEP = ("drop", "short", "long")
HIDDEN = 32
RECALL_IN = EMBED * 2
KEEP_IN = EMBED * 2 + SIGNALS


class GateNet(nn.Module):
    def __init__(self, hidden: int = HIDDEN):
        super().__init__()
        self.recall_in = nn.Sequential(nn.Linear(RECALL_IN, hidden), nn.Tanh(), nn.Dropout(0.2))
        self.keep_in = nn.Sequential(nn.Linear(KEEP_IN, hidden), nn.Tanh(), nn.Dropout(0.2))
        self.recall_out = nn.Linear(hidden, len(RECALL))
        self.keep_out = nn.Linear(hidden, len(KEEP))

    def recall_logits(self, text: Tensor, prev: Tensor) -> Tensor:
        return self.recall_out(self.recall_in(torch.cat([text, prev], -1)))

    def keep_logits(self, text: Tensor, prev: Tensor, features: Tensor) -> Tensor:
        return self.keep_out(self.keep_in(torch.cat([text, prev, features], -1)))


def recall_scores(gate: GateNet, text: Tensor, prev: Tensor) -> dict[str, float]:
    with torch.no_grad():
        p = torch.sigmoid(gate.recall_logits(text.unsqueeze(0), prev.unsqueeze(0)))[0]
    return {name: round(float(v), 4) for name, v in zip(RECALL, p)}


def keep_scores(gate: GateNet, text: Tensor, prev: Tensor, features: list[float] | None) -> dict[str, float]:
    """Features None means Jev was late or failed; the head was trained with its signals blanked for this."""
    f = torch.tensor(features if features else [0.0] * SIGNALS, dtype=torch.float32)
    with torch.no_grad():
        p = torch.softmax(gate.keep_logits(text.unsqueeze(0), prev.unsqueeze(0), f.unsqueeze(0)), -1)[0]
    return {name: round(float(v), 4) for name, v in zip(KEEP, p)}


def load_gate(path) -> GateNet:
    gate = GateNet()
    gate.load_state_dict(torch.load(path, weights_only=True))
    gate.eval().requires_grad_(False)
    return gate
