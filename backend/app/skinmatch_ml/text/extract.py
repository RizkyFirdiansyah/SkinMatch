"""Ekstraksi nama bahan dari teks OCR berbasis lexicon (SPEC-ML §6.3).

Kenapa bukan split koma: uji P0 menunjukkan OCR **menghilangkan delimiter**.
Teks `INGREDIENTS: AQUA, GLYCERIN` terbaca `INGREDIENTS AQUA GLYCERIN` — dua
bahan menyatu. Pemecahan yang bergantung koma akan kehilangan bahan.

Pendekatan di sini: longest-match terhadap lexicon (23.661 kanonik + 4.428
alias), sehingga delimiter tidak lagi menentukan.
"""

from __future__ import annotations

import csv
import re
import unicodedata
from pathlib import Path

# Kata deskriptif yang sering muncul di kemasan tetapi bukan nama bahan.
# Tanpa filter ini, "organic" atau "vegan" akan dianggap bahan.
DENYLIST: frozenset[str] = frozenset(
    {
        "organic",
        "natural",
        "vegan",
        "kosher",
        "plant",
        "plant based",
        "humectant",
        "emollient",
        "preservative",
        "dermatologist tested",
        "not tested on animals",
        "fragrance free",
    }
)

NON_ALNUM = re.compile(r"[^a-z0-9]+")
CI_PATTERN = re.compile(r"\b(c)\s*([il])\s*(\d{5})\b")


def normalize_for_match(text: str) -> str:
    """Bentuk pembanding: huruf kecil, hanya a-z0-9 dan spasi."""
    value = unicodedata.normalize("NFKC", text).lower()
    value = value.replace("\u00ad", "")  # soft hyphen
    value = value.replace("\u00b7", " ").replace("\u2022", " ")
    value = CI_PATTERN.sub(r"ci \3", value)
    value = NON_ALNUM.sub(" ", value)
    return " ".join(value.split())


def load_terms(
    lexicon_csv: str | Path,
    alias_csv: str | Path | None = None,
    min_chars: int = 4,
) -> dict[str, str]:
    """Bangun peta {bentuk ternormalisasi: nama kanonik}.

    Args:
        lexicon_csv: keluaran `scripts/build_lexicon.py` (kolom `canonical`).
        alias_csv: opsional, kolom `alias` + `canonical`.
        min_chars: abaikan bentuk yang terlalu pendek (rawan salah cocok).
    """
    mapping: dict[str, str] = {}
    blocked: set[str] = set()

    with Path(lexicon_csv).open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            canonical = (row.get("canonical") or "").strip()
            if not canonical:
                continue
            if (row.get("quality") or "ok") != "ok":
                # Entri potongan/rusak: jangan dipakai, dan alias yang menunjuk
                # ke sana juga harus dilewati.
                blocked.add(normalize_for_match(canonical))
                continue
            key = normalize_for_match(canonical)
            if len(key) >= min_chars and key not in DENYLIST:
                mapping.setdefault(key, canonical)

    if alias_csv is not None:
        with Path(alias_csv).open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                alias = (row.get("alias") or "").strip()
                canonical = (row.get("canonical") or "").strip()
                if not alias or not canonical:
                    continue
                if normalize_for_match(canonical) in blocked:
                    continue
                key = normalize_for_match(alias)
                if len(key) >= min_chars and key not in DENYLIST:
                    mapping.setdefault(key, canonical)

    # Rapikan kanonik gabungan seperti "aqua/water" atau "water/eau":
    # arahkan ke kanonik bagian pertamanya bila ada.
    for key, canonical in list(mapping.items()):
        if "/" not in canonical:
            continue
        head = normalize_for_match(canonical.split("/")[0])
        if head in mapping and mapping[head] != canonical:
            mapping[key] = mapping[head]

    return mapping


def build_trie(mapping: dict[str, str]) -> dict:
    """Trie karakter untuk pencarian longest-match."""
    root: dict = {}
    for key, canonical in mapping.items():
        node = root
        for char in key:
            node = node.setdefault(char, {})
        node[""] = canonical
    return root


class LexiconMatcher:
    """Pencocokan bahan tanpa bergantung pada delimiter."""

    def __init__(self, mapping: dict[str, str], min_chars: int = 4):
        self.mapping = mapping
        self.trie = build_trie(mapping)
        self.min_chars = min_chars

    @classmethod
    def from_files(
        cls,
        lexicon_csv: str | Path,
        alias_csv: str | Path | None = None,
        min_chars: int = 4,
    ) -> "LexiconMatcher":
        mapping = load_terms(lexicon_csv, alias_csv, min_chars=min_chars)
        return cls(mapping, min_chars=min_chars)

    def match_spans(self, text: str) -> list[tuple[int, int, str]]:
        """Posisi setiap kecocokan pada teks ternormalisasi.

        Rentang dikembalikan dalam koordinat hasil `normalize_for_match`, bukan
        teks asli. Dipakai `FuzzyLexiconMatcher` untuk mengetahui bagian mana
        yang belum dikenali.
        """
        normalized = normalize_for_match(text)
        spans: list[tuple[int, int, str]] = []

        index = 0
        length = len(normalized)
        while index < length:
            # Hanya mulai di awal kata. Tanpa batas ini, "MASSAGE" cocok dengan
            # bahan "sage" karena pencarian dimulai di tengah kata.
            if normalized[index] == " " or (index and normalized[index - 1] != " "):
                index += 1
                continue

            node = self.trie
            cursor = index
            best: str | None = None
            best_end = index

            while cursor < length and normalized[cursor] in node:
                node = node[normalized[cursor]]
                cursor += 1
                if "" in node and (cursor == length or normalized[cursor] == " "):
                    best = node[""]  # type: ignore[assignment]
                    best_end = cursor

            if best is not None:
                spans.append((index, best_end, best))
                index = best_end
            else:
                index += 1

        return spans

    def extract(self, text: str) -> list[str]:
        """Ambil bahan yang dikenali, urut kemunculan, tanpa duplikat."""
        found: list[str] = []
        seen: set[str] = set()
        for _start, _end, canonical in self.match_spans(text):
            if canonical not in seen:
                seen.add(canonical)
                found.append(canonical)
        return found


def naive_comma_split(text: str) -> list[str]:
    """Pembanding: metode naif yang bergantung pada koma.

    Dipakai di notebook sebagai baseline untuk menunjukkan kerugiannya saat
    OCR menghilangkan delimiter. Label "INGREDIENTS:" dibuang lebih dulu agar
    perbandingan adil — yang diuji adalah ketergantungan pada koma, bukan
    kemampuan membuang judul.
    """
    from .normalize import canonicalize, is_noise

    text = re.sub(
        r"^\s*(?:ingredients?|komposisi|composition)\s*[:\-]?\s*",
        "",
        text,
        flags=re.IGNORECASE,
    )

    result: list[str] = []
    seen: set[str] = set()
    for chunk in text.replace(";", ",").split(","):
        canonical, _aliases = canonicalize(chunk)
        if not canonical or is_noise(canonical) or canonical in seen:
            continue
        seen.add(canonical)
        result.append(canonical)
    return result
