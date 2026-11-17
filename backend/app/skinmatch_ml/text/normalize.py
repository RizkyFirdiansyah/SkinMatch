"""Normalisasi teks bahan — SATU sumber kebenaran.

Modul ini dipakai oleh:
  - pembentukan lexicon        (scripts/build_lexicon.py)
  - audit label                (scripts/audit_labels.py)
  - pembentukan training set   (scripts/build_trainset.py)
  - serving / inferensi        (src/skinmatch_ml/pipeline.py)

Aturan SPEC-ML §6.2: jangan pernah menyalin logika normalisasi ke tempat lain.
Perbedaan perlakuan antara training dan serving menyebabkan train/serve skew.
"""

from __future__ import annotations

import re
import unicodedata

TRADEMARK_CHARS = "®™©℠"
FOOTNOTE_CHARS = "*†‡"
SOFT_HYPHEN = "\u00ad"
DAMAGE_CHAR = "\ufffd"

PAREN_RE = re.compile(r"^(.*?)\s*\((.*)\)\s*$")
COLOR_INDEX_RE = re.compile(r"\bc[il]\s*(\d{5})\b")
COLOR_INDEX_CANON_RE = re.compile(r"^ci \d{5}$")
WHITESPACE_RE = re.compile(r"\s+")
LETTER_RE = re.compile(r"[a-z]")
URL_RE = re.compile(r"(https?://|www\.)")
NOISE_SUBSTRINGS = ("barcode", "batch", "expiry", "net wt", "directions", "warning")

# Sinonim wajib digabung agar tidak menjadi fitur ganda di TF-IDF.
# Arah: varian -> nama INCI kanonik.
SYNONYM_MERGE: dict[str, str] = {
    "water": "aqua",
    "fragrance": "parfum",
    "glycerol": "glycerin",
    "glycerine": "glycerin",
    "vitamin e": "tocopherol",
    "vitamin c": "ascorbic acid",
}


def split_ingredients(text: str) -> list[str]:
    """Pecah daftar bahan pada koma/titik-koma tingkat teratas.

    Koma di dalam tanda kurung tidak memecah:
        "Aqua (Water), Glycerin"          -> ["Aqua (Water)", "Glycerin"]

    Koma di antara dua angka juga tidak memecah, karena bagian dari nama:
        "Aqua, 1,2-Hexanediol, Glycerin"  -> ["Aqua", "1,2-Hexanediol", "Glycerin"]
    """
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    length = len(text)

    for i, ch in enumerate(text):
        if ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            depth = max(0, depth - 1)
            buf.append(ch)
        elif ch in ",;" and depth == 0:
            prev_digit = i > 0 and text[i - 1].isdigit()
            next_digit = i + 1 < length and text[i + 1].isdigit()
            if prev_digit and next_digit:
                buf.append(ch)
            else:
                parts.append("".join(buf))
                buf.clear()
        else:
            buf.append(ch)
    parts.append("".join(buf))

    return [p.strip() for p in parts if p.strip()]


def normalize_token(raw: str) -> str:
    """Normalisasi satu token bahan menjadi bentuk pembanding."""
    s = unicodedata.normalize("NFKC", raw)

    # Titik tengah / bullet sering dipakai sebagai pemisah, bukan bagian nama.
    s = s.replace("\u00b7", ",").replace("\u2022", ",")

    # Soft hyphen memutus kata ("saffl\u00adower") -> hapus.
    s = s.replace(SOFT_HYPHEN, "")

    for ch in TRADEMARK_CHARS + FOOTNOTE_CHARS:
        s = s.replace(ch, "")

    s = WHITESPACE_RE.sub(" ", s).strip().strip(".").strip().lower()

    # "Cl77491" / "ci77491" / "ci 77491" -> "ci 77491"
    s = COLOR_INDEX_RE.sub(r"ci \1", s)

    return s


def split_parenthetical(token: str) -> tuple[str, list[str]]:
    """Pisahkan nama kanonik dari keterangan dalam kurung.

    "aqua (water)"                -> ("aqua", ["water"])
    "ci 77891 (titanium dioxide)" -> ("ci 77891", ["titanium dioxide"])
    "glycerin"                    -> ("glycerin", [])
    """
    match = PAREN_RE.match(token)
    if match and match.group(1).strip():
        return match.group(1).strip(), [match.group(2).strip()]
    return token, []


def is_noise(canonical: str) -> bool:
    """True bila token bukan nama bahan yang layak dipakai."""
    if not canonical:
        return True
    if not (3 <= len(canonical) <= 80):
        return True
    # Nama Color Index ("ci 77891") hanya punya 2 huruf -> dikecualikan.
    if len(LETTER_RE.findall(canonical)) < 3 and not COLOR_INDEX_CANON_RE.match(canonical):
        return True
    if URL_RE.search(canonical):
        return True
    if any(bad in canonical for bad in NOISE_SUBSTRINGS):
        return True
    if not re.search(r"[a-z]{2,}", canonical):
        return True
    return False


def canonicalize(raw: str) -> tuple[str, list[str]]:
    """Tahap lengkap: normalisasi -> pisah kurung -> terapkan sinonim.

    Returns:
        (canonical, aliases)
    """
    normalized = normalize_token(raw)
    canonical, extras = split_parenthetical(normalized)
    canonical = SYNONYM_MERGE.get(canonical, canonical)

    aliases: list[str] = []
    for item in extras:
        if not item or is_noise(item):
            continue
        mapped = SYNONYM_MERGE.get(item, item)
        if mapped != canonical:
            aliases.append(mapped)
    return canonical, aliases
