"""Dated prices. A unit with no price is None, never 0."""
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass(frozen=True)
class PriceRow:
    provider: str
    model: str
    unit: str
    price_usd: float | None
    source: str
    checked: str


class Prices:
    def __init__(self, rows: list[PriceRow]):
        self.rows = rows
        self._by = {(r.provider, r.model, r.unit): r.price_usd for r in rows}

    @classmethod
    def load(cls, path) -> "Prices":
        return cls([PriceRow(**r) for r in yaml.safe_load(Path(path).read_text())["rows"]])

    def price(self, provider: str, model: str, unit: str) -> float | None:
        return self._by.get((provider, model, unit))
