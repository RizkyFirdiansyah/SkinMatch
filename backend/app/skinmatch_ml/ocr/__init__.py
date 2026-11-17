"""Modul OCR: pemuatan model dan ekstraksi teks."""

from .engine import (
    DEFAULT_TIER,
    MODEL_NAMES,
    create_ocr,
    default_mkldnn,
    extract_lines,
    extract_text,
)

__all__ = [
    "DEFAULT_TIER",
    "MODEL_NAMES",
    "create_ocr",
    "default_mkldnn",
    "extract_lines",
    "extract_text",
]
