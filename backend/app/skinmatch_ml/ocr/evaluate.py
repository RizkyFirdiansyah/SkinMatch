"""Metrik OCR: CER dan kemiripan teks (SPEC-ML §9.1).

CER (Character Error Rate) = edit distance / panjang referensi.
Implementasi sendiri agar tidak menambah dependensi di lingkungan service.
"""

from __future__ import annotations

import re


def normalize_for_cer(text: str) -> str:
    """Huruf kecil, hanya a-z0-9, spasi tunggal."""
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


def edit_distance(reference: str, hypothesis: str) -> int:
    """Jarak Levenshtein dengan memori O(min(n, m))."""
    if len(reference) < len(hypothesis):
        reference, hypothesis = hypothesis, reference
    if not hypothesis:
        return len(reference)

    sebelumnya = list(range(len(hypothesis) + 1))
    for i, char_ref in enumerate(reference, start=1):
        sekarang = [i]
        for j, char_hyp in enumerate(hypothesis, start=1):
            biaya = 0 if char_ref == char_hyp else 1
            sekarang.append(
                min(
                    sebelumnya[j] + 1,  # hapus
                    sekarang[j - 1] + 1,  # sisip
                    sebelumnya[j - 1] + biaya,  # ganti
                )
            )
        sebelumnya = sekarang
    return sebelumnya[-1]


def character_error_rate(reference: str, hypothesis: str) -> float:
    """CER; 0,0 = sempurna. Nilai > 1,0 berarti lebih banyak salah daripada benar."""
    ref = normalize_for_cer(reference)
    hyp = normalize_for_cer(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    return edit_distance(ref, hyp) / len(ref)


def _token_distance(reference: list[str], hypothesis: list[str]) -> int:
    """Jarak Levenshtein pada tingkat token."""
    sebelumnya = list(range(len(hypothesis) + 1))
    for i, token_ref in enumerate(reference, start=1):
        sekarang = [i]
        for j, token_hyp in enumerate(hypothesis, start=1):
            biaya = 0 if token_ref == token_hyp else 1
            sekarang.append(
                min(sebelumnya[j] + 1, sekarang[j - 1] + 1, sebelumnya[j - 1] + biaya)
            )
        sebelumnya = sekarang
    return sebelumnya[-1]


def word_error_rate(reference: str, hypothesis: str) -> float:
    """WER pada tingkat kata (bahan dipisah spasi)."""
    ref = normalize_for_cer(reference).split()
    hyp = normalize_for_cer(hypothesis).split()
    if not ref:
        return 0.0 if not hyp else 1.0
    return _token_distance(ref, hyp) / len(ref)


def grade_cer(cer: float) -> str:
    """Klasifikasi hasil sesuai ambang yang disepakati di SPEC-ML §9.1."""
    if cer < 0.05:
        return "baik"
    if cer < 0.25:
        return "terbatas"
    return "gagal"
