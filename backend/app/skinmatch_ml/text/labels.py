"""Pemetaan label weak-supervision (SPEC-ML §5.3).

Label diturunkan dari kolom `who_is_it_good_for` pada ingredientsList.csv
melalui pemetaan macro. Ini BUKAN label klinis.
"""

from __future__ import annotations

import ast
import csv
from pathlib import Path

CATEGORY_MAPPING: dict[str, tuple[str, ...]] = {
    "Berminyak_Berjerawat": (
        "Acne",
        "Blackheads",
        "Enlarged Pores",
        "Oily",
        "Post Blemish Marks",
    ),
    "Kering": ("Dry and dehydrated skin", "Fine Lines", "Wrinkles", "Elasticity"),
    "Sensitif": ("Impaired skin barrier", "Redness"),
    "Normal": (
        "Anyone",
        "Radiance",
        "Texture",
        "Pigmentation",
        "UV Protection",
        "Dark Circles",
        "Eye Bags",
    ),
}

# Urutan label MENGIKAT. Model menyimpan urutan ini di labels.json dan
# serving wajib membacanya, bukan meng-hardcode.
LABELS: tuple[str, ...] = tuple(CATEGORY_MAPPING)

_SUBTAG_TO_MACRO: dict[str, str] = {
    sub: macro for macro, subs in CATEGORY_MAPPING.items() for sub in subs
}


def parse_tag_list(value: str) -> list[str]:
    """Parse kolom `who_is_it_good_for` yang berisi repr list Python.

    Contoh isi: "[' ', 'Acne', ' ', 'Redness']"
    """
    if not value:
        return []
    try:
        parsed = ast.literal_eval(value)
    except (ValueError, SyntaxError):
        return []
    if not isinstance(parsed, (list, tuple)):
        return []
    return [" ".join(str(t).split()) for t in parsed if str(t).strip()]


def map_to_macro(tags: list[str]) -> list[str]:
    """Petakan sub-tag menjadi macro kategori (multi-label, urut sesuai LABELS)."""
    found = {_SUBTAG_TO_MACRO[t] for t in tags if t in _SUBTAG_TO_MACRO}
    return [label for label in LABELS if label in found]


def load_label_dict(path: Path) -> tuple[dict[str, list[str]], dict]:
    """Baca ingredientsList.csv menjadi {nama_kanonik: [macro, ...]}.

    Returns:
        (label_dict, stats)
    """
    from .normalize import canonicalize

    label_dict: dict[str, list[str]] = {}
    no_macro: list[str] = []
    total = 0

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            name = (row.get("name") or "").strip()
            if not name:
                continue
            total += 1
            macros = map_to_macro(parse_tag_list(row.get("who_is_it_good_for", "")))
            if not macros:
                no_macro.append(name)
            key, _ = canonicalize(name)
            label_dict[key] = macros

    stats = {
        "entries": total,
        "without_macro": len(no_macro),
        "without_macro_sample": no_macro[:20],
    }
    return label_dict, stats
