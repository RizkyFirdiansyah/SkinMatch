"""Pencocokan bahan toleran salah baca (fuzzy), melengkapi `LexiconMatcher`.

Alasan keberadaan modul ini (notebook 02): pencocokan persis menutup 0,934
recall pada teks sintetis, tetapi hanya 0,757 pada kondisi gabungan, karena OCR
salah membaca beberapa karakter (`NIACINAMIDE` -> `NIACINAMID`). Bahan yang
salah satu hurufnya keliru tidak dikenali sama sekali.

Strategi: **pencocokan persis tetap dijalankan lebih dulu**. Fuzzy hanya
menyentuh bagian teks yang belum dikenali, sehingga tidak ada regresi pada
bahan yang sudah benar. Fuzzy yang menimpa hasil persis akan menurunkan
precision.

Ambang **88** sudah ditetapkan di SPEC-ML §6.4 sebelum evaluasi dijalankan.
Konsekuensi yang harus disadari: satu huruf salah pada kata 8 karakter bernilai
87,5 (`glycerim` vs `glycerin`) sehingga **ditolak**. Ambang ini hanya menolong
kata ≥ 9 karakter. Itu harga yang dipilih untuk menekan false positive pada
lexicon 23 ribu entri — bukan bug yang perlu "diakali" dengan menurunkan ambang
setelah melihat hasil.
"""

from __future__ import annotations

import csv
from pathlib import Path

from rapidfuzz import fuzz, process

from .extract import DENYLIST, LexiconMatcher, normalize_for_match

DEFAULT_MIN_FUZZY_CHARS = 6
DEFAULT_THRESHOLD = 88.0
DEFAULT_MARGIN = 2.0
DEFAULT_MAX_NGRAM = 4

# Semakin kecil semakin diutamakan saat skor seri (SPEC-ML §6.3 langkah 6).
TIER_RANK = {"A": 0, "B": 1, "C": 2, "L": 3}


def load_fuzzy_terms(
    lexicon_csv: str | Path,
    alias_csv: str | Path | None = None,
    min_chars: int = 4,
) -> tuple[dict[str, str], dict[str, int]]:
    """Baca lexicon menjadi (peta bentuk->kanonik, peringkat tier).

    Entri dengan `quality != ok` dibuang: karakter rusak (`U+FFFD`) membuat
    jarak edit tidak bermakna dan berisiko menarik kata lain.
    """
    mapping: dict[str, str] = {}
    tier: dict[str, int] = {}

    def tambah(bentuk: str, canonical: str, tier_value: str) -> None:
        key = normalize_for_match(bentuk)
        if len(key) < min_chars or key in DENYLIST:
            return
        mapping.setdefault(key, canonical)
        tier.setdefault(key, TIER_RANK.get(tier_value, 9))

    with Path(lexicon_csv).open("r", encoding="utf-8", newline="") as handle:
        blocked: set[str] = set()
        for row in csv.DictReader(handle):
            canonical = (row.get("canonical") or "").strip()
            if (row.get("quality") or "ok") != "ok":
                if canonical:
                    blocked.add(normalize_for_match(canonical))
                continue
            if canonical:
                tambah(canonical, canonical, row.get("tier") or "C")

    if alias_csv is not None:
        with Path(alias_csv).open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                alias = (row.get("alias") or "").strip()
                canonical = (row.get("canonical") or "").strip()
                if normalize_for_match(canonical) in blocked:
                    continue
                if alias and canonical:
                    # Alias tidak punya tier sendiri; pakai tier C sementara,
                    # lalu dinaikkan mengikuti tier kanoniknya di bawah.
                    tambah(alias, canonical, row.get("tier") or "C")

    # Sama seperti `load_terms`: kanonik gabungan ("aqua/water") mengikuti
    # bentuk bagian pertamanya.
    for key, canonical in list(mapping.items()):
        if "/" not in canonical:
            continue
        head = normalize_for_match(canonical.split("/")[0])
        if head in mapping and mapping[head] != canonical:
            mapping[key] = mapping[head]

    # Satu bahan bisa punya beberapa bentuk; gunakan tier terbaik di antara
    # semuanya agar alias tidak menurunkan prioritas di fase fuzzy.
    terbaik: dict[str, int] = {}
    for key, canonical in mapping.items():
        terbaik[canonical] = min(terbaik.get(canonical, 9), tier.get(key, 9))
    for key, canonical in mapping.items():
        tier[key] = terbaik.get(canonical, 9)

    return mapping, tier


class FuzzyLexiconMatcher:
    """Longest-match persis, lalu fuzzy pada sisa yang belum dikenali."""

    def __init__(
        self,
        mapping: dict[str, str],
        tier: dict[str, int] | None = None,
        min_chars: int = 4,
        threshold: float = DEFAULT_THRESHOLD,
        margin: float = DEFAULT_MARGIN,
        min_fuzzy_chars: int = DEFAULT_MIN_FUZZY_CHARS,
        max_ngram: int = DEFAULT_MAX_NGRAM,
        allowed_tiers: tuple[int, ...] | None = (0,),
    ):
        self.mapping = mapping
        self.tier = tier or {}
        self.exact = LexiconMatcher(mapping, min_chars=min_chars)
        self.threshold = threshold
        self.margin = margin
        self.min_fuzzy_chars = min_fuzzy_chars
        self.max_ngram = max_ngram
        self.allowed_tiers = allowed_tiers

        # Kandidat fuzzy dibatasi Tier A (default). Terukur pada 300 produk
        # sintetis: semua tier P 0,792 / R 0,813; Tier A saja P 0,850 / R 0,820.
        # Tier B/C berisi nama dagang dan varian ejaan yang membuat fuzzy
        # menarik kata umum menjadi "bahan".
        # Pencocokan persis TIDAK dibatasi: string yang sama persis tetap sah.
        if tier and allowed_tiers is not None:
            kandidat = [k for k in mapping if tier.get(k, 9) in allowed_tiers]
        else:
            kandidat = list(mapping)

        # Blocking: kandidat hanya dibandingkan dengan kunci berhuruf awal sama.
        # Tanpa ini, setiap kata harus dibandingkan dengan 23 ribu entri.
        self._bucket: dict[str, list[str]] = {}
        for key in kandidat:
            self._bucket.setdefault(key[0], []).append(key)

    @classmethod
    def from_files(
        cls,
        lexicon_csv: str | Path,
        alias_csv: str | Path | None = None,
        min_chars: int = 4,
        **kwargs,
    ) -> "FuzzyLexiconMatcher":
        mapping, tier = load_fuzzy_terms(lexicon_csv, alias_csv, min_chars=min_chars)
        return cls(mapping, tier=tier, min_chars=min_chars, **kwargs)

    # --- inti -------------------------------------------------------------

    def _best_key(self, candidate: str) -> tuple[str | None, float, float]:
        """Kunci terdekat: (kunci, skor terbaik, skor terbaik kedua).

        Urutan tie-break mengikuti SPEC-ML: skor, lalu tier (A lebih dulu),
        lalu bentuk terpanjang.
        """
        panjang = len(candidate)
        toleransi = max(2, int(0.25 * panjang))
        kandidat = [
            key
            for key in self._bucket.get(candidate[0], ())
            if abs(len(key) - panjang) <= toleransi
        ]
        if not kandidat:
            return None, 0.0, 0.0

        hasil = process.extract(
            candidate,
            kandidat,
            scorer=fuzz.WRatio,
            limit=3,
            score_cutoff=0.0,
        )
        if not hasil:
            return None, 0.0, 0.0

        diurut = sorted(
            hasil,
            key=lambda item: (-item[1], self.tier.get(item[0], 9), -len(item[0])),
        )
        best_key, best_score = diurut[0][0], float(diurut[0][1])
        second = float(diurut[1][1]) if len(diurut) > 1 else 0.0
        return best_key, best_score, second

    def _fuzzy_gap(self, text: str, offset: int) -> list[tuple[int, str]]:
        """Cari bahan di bagian teks yang belum dikenali pencocokan persis."""
        tokens: list[tuple[int, str]] = []
        for token in text.split():
            pos = tokens[-1][0] + len(tokens[-1][1]) + 1 if tokens else 0
            tokens.append((pos, token))

        hasil: list[tuple[int, str]] = []
        index = 0
        while index < len(tokens):
            matched: tuple[int, str] | None = None
            max_n = min(self.max_ngram, len(tokens) - index)
            for n in range(max_n, 0, -1):
                candidate = " ".join(token for _, token in tokens[index : index + n])
                if len(candidate.replace(" ", "")) < self.min_fuzzy_chars:
                    continue
                key, score, second = self._best_key(candidate)
                if key is None or score < self.threshold:
                    continue
                if score - second < self.margin:
                    continue
                matched = (n, self.mapping[key])
                break

            if matched is None:
                index += 1
                continue
            n, canonical = matched
            hasil.append((offset + tokens[index][0], canonical))
            index += n

        return hasil

    def extract(self, text: str) -> list[str]:
        """Bahan yang dikenali, urut kemunculan, tanpa duplikat."""
        normalized = normalize_for_match(text)
        spans = self.exact.match_spans(text)

        kandidat: list[tuple[int, str]] = [
            (start, canonical) for start, _end, canonical in spans
        ]

        cursor = 0
        for start, end, _canonical in spans:
            if start > cursor:
                kandidat.extend(self._fuzzy_gap(normalized[cursor:start], cursor))
            cursor = max(cursor, end)
        if cursor < len(normalized):
            kandidat.extend(self._fuzzy_gap(normalized[cursor:], cursor))

        kandidat.sort(key=lambda item: item[0])

        found: list[str] = []
        seen: set[str] = set()
        for _pos, canonical in kandidat:
            if canonical not in seen:
                seen.add(canonical)
                found.append(canonical)
        return found
