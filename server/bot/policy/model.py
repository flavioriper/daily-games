# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""The policy network (spec section 4): a frozen base plus weight deltas summed in, the stop rule, and a "learned from" explanation."""
from dataclasses import dataclass

import torch
from torch import Tensor, nn
from torch.func import functional_call

from policy.features import DIM, FEATURE_NAMES, KINDS
from policy.labels import HEADS, Decision

STOP_INDEX = KINDS.index("stop")
STOP_RULE = 0.7
SIZES = [len(v) for v in HEADS.values()]


class PolicyNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(nn.Linear(DIM, 32), nn.Tanh(), nn.Linear(32, sum(SIZES)))

    def forward(self, x: Tensor) -> Tensor:
        return self.net(x)

    def heads(self, logits: Tensor) -> dict[str, Tensor]:
        return dict(zip(HEADS, torch.split(logits, SIZES, dim=-1)))


class Delta:
    """A zero-initialised set of weights with the base's shapes, added to it in the forward pass."""

    def __init__(self, tensors: dict[str, Tensor]):
        self.tensors = tensors

    @classmethod
    def zeros(cls) -> "Delta":
        return cls({k: torch.zeros_like(v) for k, v in PolicyNet().state_dict().items()})

    def norm(self) -> float:
        return float(torch.sqrt(sum((t.detach() ** 2).sum() for t in self.tensors.values())))

    def clone(self) -> "Delta":
        return Delta({k: v.detach().clone() for k, v in self.tensors.items()})

    def save(self, path) -> None:
        torch.save({k: v.detach() for k, v in self.tensors.items()}, path)

    @classmethod
    def load(cls, path) -> "Delta":
        return cls(torch.load(path, weights_only=True))


def forward_with(net: PolicyNet, deltas: list[Delta], x: Tensor) -> dict[str, Tensor]:
    params = {k: v.detach() for k, v in net.named_parameters()}
    for d in deltas:
        params = {k: params[k] + d.tensors[k] for k in params}
    return net.heads(functional_call(net, params, (x,)))


@dataclass
class Prediction:
    decision: Decision
    probabilities: dict[str, dict[str, float]]
    explanation: dict[str, list[str]]
    override: str | None


def predict(net: PolicyNet, deltas: list[Delta], features: list[float]) -> Prediction:
    x = torch.tensor(features, dtype=torch.float32, requires_grad=True)
    out = forward_with(net, deltas, x)
    probs = {h: torch.softmax(out[h], -1) for h in HEADS}
    chosen = {h: HEADS[h][int(probs[h].argmax())] for h in HEADS}
    override = None
    if features[STOP_INDEX] >= STOP_RULE:
        chosen["stance"], chosen["ack"] = "hold", "no"
        override = "rule: stop"
    explanation = {}
    for h in HEADS:
        (grad,) = torch.autograd.grad(torch.log_softmax(out[h], -1)[HEADS[h].index(chosen[h])], x, retain_graph=True)
        top = torch.argsort((grad * x).abs().detach(), descending=True)[:3]
        explanation[h] = [FEATURE_NAMES[i] for i in top.tolist()]
    return Prediction(
        Decision(**chosen),
        {h: dict(zip(HEADS[h], probs[h].detach().tolist())) for h in HEADS},
        explanation,
        override,
    )


def anatomy(net: PolicyNet, persona: Delta, user: Delta, features: list[float], edges: int = 60) -> dict:
    """The network's insides for one turn, for the presenter page: inputs, hidden activations, the strongest weighted edges of the
    combined weights, and each head's choice at three stages (base alone, + persona delta, + user delta). No stop rule here."""
    x = torch.tensor(features, dtype=torch.float32)
    with torch.no_grad():
        w = {k: v.detach() + persona.tensors[k] + user.tensors[k] for k, v in net.state_dict().items()}
        hidden = torch.tanh(w["net.0.weight"] @ x + w["net.0.bias"])

        def strongest(m: Tensor) -> list[list]:
            flat = m.abs().flatten()
            top = torch.argsort(flat, descending=True)[:edges]
            cols = m.shape[1]
            return [[int(i % cols), int(i // cols), round(float(m.flatten()[i]), 4)] for i in top]

        stages = {}
        for name, deltas in (("base", []), ("persona", [persona]), ("you", [persona, user])):
            out = forward_with(net, deltas, x)
            stages[name] = {}
            for h in HEADS:
                p = torch.softmax(out[h], -1)
                stages[name][h] = {"choice": HEADS[h][int(p.argmax())], "probabilities": dict(zip(HEADS[h], [round(v, 4) for v in p.tolist()]))}
    return {
        "inputs": [round(v, 4) for v in features],
        "hidden": [round(v, 4) for v in hidden.tolist()],
        # [from, to, weight × activation]: input i → hidden j, and hidden j → output k
        "edges_in": strongest(w["net.0.weight"] * x),
        "edges_out": strongest(w["net.2.weight"] * hidden),
        "stages": stages,
    }
