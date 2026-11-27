"""Pembuat label sintetis + degradasi bergaya foto (SPEC-ML §7.3).

Dipakai `notebooks/01_ocr.ipynb` untuk mengukur CER per kondisi tanpa menunggu
30 foto asli. Gambar sintetis **bukan** pengganti gold standard — ia hanya
memisahkan "apakah OCR bisa membaca teks bersih" dari "apakah kamera cukup baik".
"""

from __future__ import annotations

import textwrap

import cv2
import numpy as np

KONDISI: tuple[str, ...] = (
    "bersih",
    "putar",
    "blur",
    "kontras",
    "perspektif",
    "silau",
    "gabungan",
)

FONT_PATH = r"C:\Windows\Fonts\arial.ttf"


def render_label(text: str, width: int = 960, font_size: int = 26) -> np.ndarray:
    """Render teks bahan menjadi gambar label putih dengan huruf hitam."""
    from PIL import Image, ImageDraw, ImageFont

    try:
        font = ImageFont.truetype(FONT_PATH, font_size)
    except OSError:  # pragma: no cover - font tidak tersedia
        font = ImageFont.load_default()

    baris = textwrap.wrap(text, width=52) or [""]
    tinggi_baris = int(font_size * 1.6)
    margin = 28
    height = margin * 2 + tinggi_baris * (len(baris) + 1)

    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    draw.text((margin, margin), "INGREDIENTS", fill="black", font=font)
    for i, line in enumerate(baris):
        draw.text(
            (margin, margin + tinggi_baris * (i + 1)),
            line,
            fill="black",
            font=font,
        )

    return cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)


def _perspective(image: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    h, w = image.shape[:2]
    geser = int(min(h, w) * 0.06)
    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = np.float32(
        [
            [rng.integers(0, geser), rng.integers(0, geser)],
            [w - rng.integers(0, geser), rng.integers(0, geser)],
            [w - rng.integers(0, geser), h - rng.integers(0, geser)],
            [rng.integers(0, geser), h - rng.integers(0, geser)],
        ]
    )
    matrix = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(
        image, matrix, (w, h), borderValue=(255, 255, 255)
    )


def _glare(image: np.ndarray) -> np.ndarray:
    h, w = image.shape[:2]
    overlay = np.zeros((h, w, 3), dtype=np.uint8)
    cv2.ellipse(
        overlay,
        (int(w * 0.65), int(h * 0.35)),
        (int(w * 0.30), int(h * 0.22)),
        25,
        0,
        360,
        (255, 255, 255),
        -1,
    )
    mask = cv2.GaussianBlur(overlay, (0, 0), sigmaX=w * 0.03)
    return cv2.addWeighted(image, 1.0, mask, 0.85, 0)


def degrade(image: np.ndarray, kondisi: str, seed: int = 0) -> np.ndarray:
    """Terapkan satu kondisi degradasi. `gabungan` = semua kondisi sekaligus."""
    if kondisi not in KONDISI:
        raise ValueError(f"kondisi tidak dikenal: {kondisi}. Pilihan: {KONDISI}")

    rng = np.random.default_rng(seed)
    hasil = image.copy()

    aktif = (
        {"putar", "blur", "kontras", "perspektif", "silau"}
        if kondisi == "gabungan"
        else {kondisi}
    )

    if "putar" in aktif:
        h, w = hasil.shape[:2]
        matrix = cv2.getRotationMatrix2D((w / 2, h / 2), 9.0, 1.0)
        hasil = cv2.warpAffine(
            hasil, matrix, (w, h), borderValue=(255, 255, 255)
        )

    if "perspektif" in aktif:
        hasil = _perspective(hasil, rng)

    if "blur" in aktif:
        hasil = cv2.GaussianBlur(hasil, (0, 0), sigmaX=1.6)

    if "kontras" in aktif:
        hasil = cv2.convertScaleAbs(hasil, alpha=0.55, beta=45)

    if "silau" in aktif:
        hasil = _glare(hasil)

    return hasil
