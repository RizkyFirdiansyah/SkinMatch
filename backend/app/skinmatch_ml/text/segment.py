"""Pemecahan daftar bahan tanpa bergantung pada koma.

Latar belakang (SPEC-ML §12.7): pada foto kemasan nyata, koma sering hilang
sebagian, dan OCR memutus kata di tanda hubung (`GLYCOL DISTEA- RATE`,
`HYDROLY- SATE`). Kalau daftar bahan diturunkan hanya dengan `split(",")`, dua
akibat muncul:

1. beberapa bahan tergabung menjadi satu item panjang, dan
2. matcher lexicon mencocokkan potongan kata sehingga menghasilkan "bahan"
   palsu seperti `glycol`, `palmitate`, `steareth`.

Modul ini dipakai `scripts/finalize_annotation.py`. Aturannya sengaja
konservatif: koma tetap dipakai bila cukup banyak, dan lexicon hanya menjadi
alat bantu segmentasi ketika koma tidak bisa diandalkan. Nama yang tidak dikenal
lexicon **tidak dibuang** — bisa jadi bahan baru atau nama dagang.
"""

from __future__ import annotations

import re

from .extract import LexiconMatcher, normalize_for_match

# Kata/penanda yang menandakan teks di luar daftar bahan. Dipakai untuk
# membuang ekor blok yang lolos dari pemotongan `ocr.section`.
MARKETING_MARKERS: frozenset[str] = frozenset(
    {
        "bpom",
        "netto",
        "net wt",
        "berat bersih",
        "dermatologis",
        "dermatologist",
        "hypoallergenic",
        "non comedogenic",
        "manfaat",
        "khasiat",
        "cara pakai",
        "petunjuk",
        "peringatan",
        "caution",
        "warning",
        "exp",
        "expired",
        "batch",
        "lot",
        "no registrasi",
        "nomor registrasi",
        "diproduksi",
        "manufactured",
        "distributed",
        "imported",
        "made in",
        "terdaftar",
        "kemasan",
        "produksi",
    }
)

# Satuan berat/volume: ciri teks kemasan, bukan nama bahan.
UNIT_PATTERN = re.compile(r"\b\d+(?:[.,]\d+)?\s*(?:ml|l|g|gr|mg|kg|oz)\b", re.IGNORECASE)

# Penanda yang memotong teks: apa pun setelahnya bukan daftar bahan. Dibangun
# dari MARKETING_MARKERS agar tidak ada daftar ganda yang bisa melenceng.
TAIL_PATTERN = re.compile(
    r"\b(?:" + "|".join(re.escape(marker) for marker in sorted(MARKETING_MARKERS, key=len, reverse=True)) + r")\b",
    re.IGNORECASE,
)

HEADING = re.compile(
    r"^\s*(?:ingredients?|komposisi|composition|kandungan)\s*[:\-]?\s*",
    re.IGNORECASE,
)

# Tanda hubung di akhir baris: "DISTEA- RATE" -> "DISTEARATE".
HYPHEN_BREAK = re.compile(r"(?<=\S)-\s+")

# Delimiter bahan. Koma di antara dua angka **bukan** pemisah bahan:
# `1,2-hexanediol` dan `1,2-propanediol` adalah satu nama INCI. Tanpa
# pengecualian ini, nama tersebut terpecah menjadi `1` + `2 hexanediol`
# sehingga daftar bahan berisi nama yang tidak pernah tercetak di kemasan.
_DELIM = r"(?:(?<!\d)[,;]|[,;](?!\d))|(?<=[A-Za-z])\.(?=\s)|(?<=[A-Za-z])\.(?=[A-Za-z])"
DELIMITER = re.compile(_DELIM)

# Item yang isinya hanya kata sambung/penghubung.
STOPWORDS: frozenset[str] = frozenset(
    {"dan", "and", "atau", "or", "with", "dengan", "contains", "mengandung"}
)


def join_hyphen_breaks(text: str) -> str:
    """Satukan kata yang terpotong tanda hubung di akhir baris."""
    return HYPHEN_BREAK.sub("", text)


def strip_heading(text: str) -> str:
    """Buang judul blok (`INGREDIENTS:` / `KOMPOSISI:`) di awal teks."""
    return HEADING.sub("", text.strip(), count=1)


def cut_marketing_tail(text: str) -> str:
    """Potong teks mulai penanda non-bahan pertama.

    Tanpa ini, ekor seperti `... PHENOXYETHANOL. BPOM RI ...` membuat bahan
    terakhir ikut terbuang saat item difilter.
    """
    match = TAIL_PATTERN.search(text)
    return text[: match.start()] if match else text


def _clean_item(raw: str) -> str:
    item = join_hyphen_breaks(raw)
    item = item.replace("\n", " ")
    item = re.sub(r"\s+", " ", item).strip(" \t,;:.-—–()[]")
    return item.lower()


def looks_like_marketing(item: str) -> bool:
    """True bila item mengandung penanda teks non-bahan."""
    normalized = normalize_for_match(item)
    if not normalized:
        return True
    padded = f" {normalized} "
    if any(f" {marker} " in padded for marker in MARKETING_MARKERS):
        return True
    return bool(UNIT_PATTERN.search(item))


def _is_usable(item: str) -> bool:
    if len(item) < 3:
        return False
    if item in STOPWORDS:
        return False
    if looks_like_marketing(item):
        return False
    # Item tanpa huruf (mis. "1 2 3") bukan bahan.
    if not re.search(r"[a-z]", item):
        return False
    return True


def _dedupe(items: list[str]) -> list[str]:
    hasil: list[str] = []
    seen: set[str] = set()
    for item in items:
        key = normalize_for_match(item)
        if not key or key in seen:
            continue
        seen.add(key)
        hasil.append(item)
    return hasil


def _split_on_commas(text: str) -> list[str]:
    # Titik juga dipakai OCR sebagai pengganti koma ("aqua. glycerin"), tetapi
    # hanya titik setelah huruf kecil dan diikuti spasi — supaya "FIL.1747.V00"
    # dan "CI77266." tidak ikut terpecah. Koma di dalam angka tidak dipisah.
    chunks = DELIMITER.split(text)
    return [_clean_item(chunk) for chunk in chunks]


def _count_delimiters(text: str) -> int:
    return len(DELIMITER.findall(text))


def _residue_candidates(text: str, covered: list[tuple[int, int]]) -> list[str]:
    """Potongan teks yang tidak dikenali lexicon, calon nama tak dikenal.

    Hanya dipakai pada mode segmentasi. Dipotong lagi per tanda baca agar klaim
    pemasaran yang menempel tidak ikut masuk.
    """
    chars = list(text)
    for start, end in covered:
        for index in range(max(start, 0), min(end, len(chars))):
            chars[index] = " "
    residue = "".join(chars)
    kandidat: list[str] = []
    for chunk in re.split(r"[,;/|()\[\]]|\.", residue):
        item = _clean_item(chunk)
        if _is_usable(item) and len(item.split()) <= 5:
            kandidat.append(item)
    return kandidat


def _split_with_lexicon(text: str, matcher: LexiconMatcher) -> list[str]:
    normalized = normalize_for_match(text)
    spans = matcher.match_spans(text)
    hasil = [canonical.lower() for _start, _end, canonical in spans]

    # `match_spans` mengembalikan koordinat teks ternormalisasi; residu dihitung
    # pada teks ternormalisasi yang sama supaya posisinya sejajar.
    hasil.extend(_residue_candidates(normalized, [(a, b) for a, b, _ in spans]))
    return hasil


def _resegment_long(items: list[str], matcher: LexiconMatcher) -> list[str]:
    """Pecah lagi item panjang dengan lexicon.

    Koma bisa hilang hanya di sebagian baris, sehingga pemecahan koma
    menyisakan satu item berisi banyak bahan. Item seperti itu dipecah ulang
    memakai lexicon; bila lexicon tidak menemukan apa pun, item asli dipakai.
    """
    hasil: list[str] = []
    for item in items:
        if len(item.split()) <= 6:
            hasil.append(item)
            continue
        potongan = _split_with_lexicon(item, matcher)
        if len(potongan) >= 2:
            hasil.extend(potongan)
        else:
            hasil.append(item)
    return hasil


def split_ingredients(
    text: str,
    matcher: LexiconMatcher | None = None,
    min_commas: int = 3,
) -> list[str]:
    """Turunkan daftar bahan dari teks blok komposisi.

    Args:
        text: isi `ingredients_text` (sudah dikoreksi manusia atau masih draft).
        matcher: diperlukan untuk mode segmentasi saat koma tidak cukup.
        min_commas: jumlah koma minimum agar pemecahan koma dipakai.

    Returns:
        Daftar bahan huruf kecil, urut kemunculan, tanpa duplikat.

    Raises:
        ValueError: teks memerlukan segmentasi tetapi `matcher` tidak diberikan.
    """
    if not text or not text.strip():
        return []

    bersih = join_hyphen_breaks(text.replace("\r", "\n"))
    bersih = strip_heading(bersih)
    bersih = cut_marketing_tail(bersih)

    if _count_delimiters(bersih) >= min_commas:
        hasil = _split_on_commas(bersih)
    else:
        if matcher is None:
            raise ValueError(
                "teks tanpa koma cukup; sertakan matcher lexicon untuk segmentasi"
            )
        hasil = _split_with_lexicon(bersih, matcher)

    hasil = _dedupe([item for item in hasil if _is_usable(item)])
    if matcher is not None:
        hasil = _dedupe(_resegment_long(hasil, matcher))
    return hasil


def suspicious_items(items: list[str], matcher: LexiconMatcher | None = None) -> dict:
    """Ringkasan item yang perlu diperiksa manusia (dipakai mode --check)."""
    mapping = set(matcher.mapping) if matcher is not None else set()
    terlalu_panjang = [item for item in items if len(item.split()) > 6]
    pemasaran = [item for item in items if looks_like_marketing(item)]
    tak_dikenal = [
        item
        for item in items
        if mapping and normalize_for_match(item) not in mapping
    ]
    return {
        "n": len(items),
        "lebih_6_kata": terlalu_panjang,
        "kata_pemasaran": pemasaran,
        "tak_dikenal": tak_dikenal,
    }
