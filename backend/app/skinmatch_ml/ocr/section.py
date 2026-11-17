"""Pemotongan blok komposisi dari teks OCR.

Dipakai untuk dua hal yang harus konsisten:

1. membuat draft anotasi (`scripts/draft_annotations.py`), dan
2. menilai CER (`scripts/evaluate_end_to_end.py`).

Kalau keduanya memotong teks dengan cara berbeda, CER akan mengukur kesalahan
pemotongan, bukan kesalahan OCR.

Catatan keadilan penilaian: blok komposisi di kemasan biasanya diikuti teks lain
("MADE IN", nomor batch, alamat distributor, peringatan). Teks itu tidak termasuk
ground truth, sehingga harus dipotong juga — kalau tidak, CER membesar karena
informasi yang memang tidak dinilai.

Penanda akhir sengaja dibuat panjang dan mencakup bahasa Indonesia, karena
penyebab CER tinggi pada foto asli bukan salah baca OCR, melainkan ekor
kemasan yang ikut terbaca (lihat SPEC-ML §12.3).
"""

from __future__ import annotations

import re

# Penanda awal blok komposisi. "bahan" ditaruh paling akhir karena kata itu
# sering muncul lebih awal dalam kalimat pemasaran berbahasa Indonesia.
MARKER_AWAL = re.compile(
    r"\b(ingredients?|komposisi|composition|kandungan|bahan)\b",
    re.IGNORECASE,
)

# Penanda akhir: apa pun setelah ini bukan bagian daftar bahan.
MARKER_AKHIR = re.compile(
    r"\b("
    # peringatan / petunjuk (Inggris & Indonesia)
    r"cautions?|warnings?|directions?|how to use|usage|petunjuk|peringatan|"
    r"perhatian|jauhkan|hindari|konsultasikan|pemakaian luar|cara pakai|"
    r"cara penggunaan|"
    # produksi / distribusi
    r"made in|manufactured|produced for|diproduksi|didistribusikan oleh|"
    r"distributed by|imported by|importir|distributor|"
    # identitas & administrasi
    r"expiration|exp date|expiry|exp\.|best before|mfd|nomor batch|batch no|"
    r"no\. registrasi|nomor registrasi|bpom|kode produksi|"
    r"net wt|net weight|netto|berat bersih|barcode|halal|"
    # kontak
    r"customer care|layanan konsumen|toll free|email|e-mail|www\.|phone|"
    r"telp|whatsapp"
    r")\b",
    re.IGNORECASE,
)


def find_block_start(text: str) -> int | None:
    """Indeks awal blok komposisi, atau None bila penanda tidak ditemukan."""
    match = MARKER_AWAL.search(text)
    return match.start() if match else None


def extract_ingredients_block(text: str) -> tuple[str, bool]:
    """Ambil blok komposisi saja.

    Returns:
        (teks_blok, penanda_ditemukan)
    """
    if not text:
        return "", False

    start = find_block_start(text)
    if start is not None:
        sisa = text[start:]
        akhir = MARKER_AKHIR.search(sisa, pos=1)
        if akhir is not None:
            sisa = sisa[: akhir.start()]
        return sisa.strip(" ,;:-"), True

    # Tanpa penanda awal: tetap potong ekornya bila ada. Untuk teks acuan
    # (anotasi manusia) ini tidak mengubah apa pun karena teksnya sudah bersih.
    akhir = MARKER_AKHIR.search(text, pos=1)
    if akhir is not None and akhir.start() > 0:
        text = text[: akhir.start()]
    return text.strip(" ,;:-"), False
