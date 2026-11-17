"""Pembacaan training set hasil `scripts/build_trainset.py`."""

from __future__ import annotations

import csv
from pathlib import Path

import numpy as np

from ..text.labels import LABELS


def load_trainset(path: str | Path) -> tuple[list[str], np.ndarray, tuple[str, ...], list[dict]]:
    """Baca CSV training set menjadi (teks_bahan, matriks_label, label, baris).

    Returns:
        texts  : string bahan kanonik dipisah ', '
        Y      : matriks int (n, 4) berisi 0/1
        labels : urutan label yang mengikat
        rows   : baris mentah untuk inspeksi
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(
            f"Training set tidak ada: {path}\n"
            "Jalankan dulu: python scripts/build_trainset.py"
        )

    texts: list[str] = []
    targets: list[list[int]] = []
    rows: list[dict] = []

    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            present = {part for part in (row.get("labels") or "").split("|") if part}
            texts.append(row.get("ingredients_canonical") or "")
            targets.append([1 if label in present else 0 for label in LABELS])
            rows.append(row)

    return texts, np.asarray(targets, dtype=int), LABELS, rows


def label_prevalence(Y: np.ndarray, labels: tuple[str, ...]) -> dict[str, float]:
    return {
        label: round(float(Y[:, i].mean()), 4)
        for i, label in enumerate(labels)
    }
