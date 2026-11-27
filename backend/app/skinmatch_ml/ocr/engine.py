"""Modul OCR: pemuatan model dan ekstraksi teks.

Satu sumber kebenaran untuk training, verifikasi P0, dan serving. Jangan
menyalin logika pemuatan model ke tempat lain (SPEC-ML §6.2).
"""

from __future__ import annotations

import logging
import platform
from typing import Any

logger = logging.getLogger(__name__)

# Tier dipilih lewat NAMA MODEL, bukan `ocr_version`.
# `ocr_version` hanya menerima versi mayor (PP-OCRv3..v6).
MODEL_NAMES: dict[str, tuple[str, str]] = {
    "tiny": ("PP-OCRv6_tiny_det", "PP-OCRv6_tiny_rec"),
    "small": ("PP-OCRv6_small_det", "PP-OCRv6_small_rec"),
    "medium": ("PP-OCRv6_medium_det", "PP-OCRv6_medium_rec"),
}

# Default `small`: `medium` 16x lebih lambat dengan mutu teks setara pada foto
# asli (SPEC-ML §12.5). `tiny` hanya kandidat cadangan, belum dinilai pada anotasi.
DEFAULT_TIER = "small"


def default_mkldnn() -> bool:
    """oneDNN mati di Windows.

    Paddle 3.3.1 di Windows gagal saat inferensi dengan
        (Unimplemented) ConvertPirAttribute2RuntimeAttribute not support
    pada jalur oneDNN (PIR executor). Di Linux jalur tersebut normal dan
    justru menjadi sumber kecepatan, jadi dibiarkan aktif.
    """
    return platform.system() != "Windows"


def create_ocr(
    tier: str = DEFAULT_TIER,
    mkldnn: bool | None = None,
    device: str = "cpu",
    textline_orientation: bool = False,
):
    """Buat instance PaddleOCR.

    Args:
        tier: "tiny" | "small" | "medium".
        mkldnn: None = ikut `default_mkldnn()`.
        device: "cpu" (produksi HF Spaces) atau "gpu".
        textline_orientation: klasifikasi 0/180° per baris. **Default mati.**

    Raises:
        ValueError: tier tidak dikenal.
        ImportError: paddleocr tidak terpasang.

    Catatan `textline_orientation` (terukur 13 Nov 2026, foto asli G01):
        Dengan opsi ini AKTIF, garis "INGREDIENTS: AQUA, POTASSIUM PALM
        KERNELATE, ..." terbaca sebagai sampah ("HossP pup aaPl a ouo wrol")
        karena classifier 0/180 salah membalik baris yang sudah tegak.
        Dengan opsi MATI, seluruh blok bahan terbaca dengan skor 0,97-0,99.

        Klien sudah mengirim hasil crop yang tegak, jadi orientasi per baris
        tidak diperlukan. Membiarkannya aktif bukan hanya memperlambat
        (model tambahan per baris) tetapi juga MERUSAK akurasi.
    """
    if tier not in MODEL_NAMES:
        raise ValueError(
            f"tier tidak dikenal: {tier!r}. Pilihan: {', '.join(MODEL_NAMES)}"
        )

    from paddleocr import PaddleOCR

    if mkldnn is None:
        mkldnn = default_mkldnn()

    det, rec = MODEL_NAMES[tier]
    kwargs: dict[str, Any] = {
        "text_detection_model_name": det,
        "text_recognition_model_name": rec,
        "use_doc_orientation_classify": False,
        "use_doc_unwarping": False,
        "use_textline_orientation": textline_orientation,
        "device": device,
        "enable_mkldnn": mkldnn,
    }

    # Toleransi versi: buang parameter yang tidak dikenal, satu per satu.
    while True:
        try:
            return PaddleOCR(**kwargs)
        except TypeError as exc:
            message = str(exc)
            removable = [key for key in kwargs if key in message]
            if not removable:
                # Tidak bisa ditebak: matikan mkldnn sebagai langkah aman.
                removable = ["enable_mkldnn"] if "enable_mkldnn" in kwargs else []
            if not removable:
                raise
            for key in removable:
                kwargs.pop(key, None)
                logger.warning("parameter PaddleOCR tidak didukung: %s", key)


def extract_text(results) -> tuple[list[str], list[float]]:
    """Ambil teks dan skor dari keluaran PaddleOCR (3.x, dengan fallback 2.x)."""
    texts: list[str] = []
    scores: list[float] = []

    for res in results or []:
        try:
            texts.extend(res["rec_texts"])
            scores.extend(float(s) for s in res["rec_scores"])
            continue
        except Exception:
            pass
        try:  # bentuk lama: [[box, (text, score)], ...]
            for line in res or []:
                texts.append(line[1][0])
                scores.append(float(line[1][1]))
        except Exception:
            continue

    return texts, scores


def extract_lines(results) -> list[dict]:
    """Keluaran siap-JSON: teks, skor, dan kotak poligon per baris."""
    lines: list[dict] = []
    for res in results or []:
        try:
            texts = res["rec_texts"]
            scores = res["rec_scores"]
            polys = res.get("rec_polys", res.get("dt_polys"))
        except Exception:
            continue
        for index, text in enumerate(texts):
            score = float(scores[index]) if index < len(scores) else None
            poly = None
            if polys is not None and index < len(polys):
                poly = [[float(x), float(y)] for x, y in polys[index]]
            lines.append({"text": text, "score": score, "poly": poly})
    return lines
