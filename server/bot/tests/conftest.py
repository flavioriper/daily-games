import json
from pathlib import Path

import pytest
import torch

from policy.model import PolicyNet
from studio.card import Card


def load_base() -> PolicyNet:
    net = PolicyNet()
    net.load_state_dict(torch.load("models/base.pt", weights_only=True))
    net.requires_grad_(False)
    return net


@pytest.fixture
def card() -> Card:
    return Card.model_validate(json.loads(Path("tests/fixtures/card.json").read_text()))
