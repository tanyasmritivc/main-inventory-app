"""Inventory group categories. Category does not change licensing or access."""

from typing import Literal, get_args

TeamCategory = Literal[
    "agriculture",
    "art_design",
    "automotive",
    "business",
    "club",
    "construction",
    "custom",
    "education",
    "electronics",
    "engineering",
    "hospitality",
    "manufacturing",
    "fll",
    "frc",
    "ftc",
    "healthcare",
    "household",
    "laboratory",
    "logistics",
    "makerspace",
    "nonprofit",
    "office",
    "other",
    "research",
    "retail",
    "robotics",
    "sports",
    "studio",
    "vex",
]
VALID_PROGRAMS = frozenset(get_args(TeamCategory))


def normalize_custom_category(program: str, label: str | None) -> str | None:
    label = (label or "").strip()
    if program != "custom":
        if label:
            raise ValueError("A custom category is only allowed when Custom category is selected")
        return None
    if not label or len(label) > 60 or any(ord(c) < 32 or ord(c) == 127 for c in label):
        raise ValueError("Enter a custom category of 1 to 60 characters on one line")
    return label
