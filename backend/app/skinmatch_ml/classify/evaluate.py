"""Metrik evaluasi multi-label + baseline trivial (SPEC-ML §9).

Alasan baseline wajib: pada dataset ini `Normal` muncul di 85% produk, sehingga
classifier yang selalu menjawab "semua cocok" sudah mendapat macro-F1 tinggi.
Tanpa baseline, angka itu mudah disalahartikan sebagai kemampuan model.
"""

from __future__ import annotations

from collections import Counter

import numpy as np


def per_label_f1(y_true: np.ndarray, y_pred: np.ndarray, label: str) -> dict:
    """Precision, recall, F1 untuk satu kolom label (irisan biner)."""
    true = y_true.astype(bool)
    pred = y_pred.astype(bool)

    tp = int(np.sum(true & pred))
    fp = int(np.sum(~true & pred))
    fn = int(np.sum(true & ~pred))

    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (
        2 * precision * recall / (precision + recall)
        if (precision + recall)
        else 0.0
    )
    return {
        "label": label,
        "support": int(np.sum(true)),
        "precision": round(precision, 3),
        "recall": round(recall, 3),
        "f1": round(f1, 3),
    }


def subset_accuracy(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    """Proporsi produk yang seluruh 4 label-nya tepat sama."""
    return float(np.mean(np.all(y_true == y_pred, axis=1)))


def hamming_loss(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    """Proporsi sel label yang salah."""
    return float(np.mean(y_true != y_pred))


def summarize(
    y_true: np.ndarray, y_pred: np.ndarray, labels: tuple[str, ...]
) -> dict:
    per_label = [
        per_label_f1(y_true[:, i], y_pred[:, i], labels[i])
        for i in range(len(labels))
    ]
    return {
        "macro_f1": round(float(np.mean([m["f1"] for m in per_label])), 3),
        "micro_f1": _micro_f1(y_true, y_pred),
        "subset_accuracy": round(subset_accuracy(y_true, y_pred), 3),
        "hamming_loss": round(hamming_loss(y_true, y_pred), 3),
        "per_label": per_label,
    }


def _micro_f1(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    true = y_true.astype(bool).ravel()
    pred = y_pred.astype(bool).ravel()
    tp = int(np.sum(true & pred))
    fp = int(np.sum(~true & pred))
    fn = int(np.sum(true & ~pred))
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    if precision + recall == 0:
        return 0.0
    return round(2 * precision * recall / (precision + recall), 3)


def trivial_predictions(y_train: np.ndarray, n_rows: int, labels) -> dict:
    """Dua baseline yang harus dikalahkan model sungguhan."""
    all_ones = np.ones((n_rows, len(labels)), dtype=int)

    prevalence = y_train.mean(axis=0)
    most_common = int(np.argmax(prevalence))
    most_common_only = np.zeros((n_rows, len(labels)), dtype=int)
    most_common_only[:, most_common] = 1

    return {
        "semua_label": all_ones,
        "label_terbanyak": most_common_only,
        "label_terbanyak_nama": labels[most_common],
    }


def label_combination_counts(
    y: np.ndarray, labels: tuple[str, ...], top: int = 8
) -> list[tuple[str, int]]:
    """Kombinasi label terbanyak — untuk melihat saturasi target."""
    counter: Counter = Counter()
    for row in y:
        combo = " + ".join(labels[i] for i, value in enumerate(row) if value)
        counter[combo or "(kosong)"] += 1
    return counter.most_common(top)


def tune_thresholds(
    scores: np.ndarray,
    y_true: np.ndarray,
    labels: tuple[str, ...],
    grid: tuple[float, ...] = (0.2, 0.3, 0.4, 0.5, 0.6, 0.7),
) -> tuple[dict[str, float], dict[str, float]]:
    """Pilih ambang per label yang memaksimalkan F1 pada data validasi.

    Penting: dipanggil pada data validasi, BUKAN test. Menyetel ambang di test
    membuat hasil terlihat lebih baik dari kenyataan.
    """
    best: dict[str, float] = {}
    best_f1: dict[str, float] = {}
    for i, label in enumerate(labels):
        scores_i = scores[:, i]
        column = y_true[:, i]
        top_threshold, top_score = grid[0], -1.0
        for threshold in grid:
            pred = (scores_i >= threshold).astype(int)
            f1 = per_label_f1(column, pred, label)["f1"]
            if f1 > top_score:
                top_threshold, top_score = threshold, f1
        best[label] = top_threshold
        best_f1[label] = top_score
    return best, best_f1
