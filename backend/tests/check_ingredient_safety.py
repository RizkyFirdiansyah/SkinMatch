"""Cek mandiri tabel aturan keamanan bahan (Fitur 1).

Jalankan dari folder `backend/`:

    .venv/Scripts/python.exe tests/check_ingredient_safety.py

Tanpa pytest — cukup assert. Keluar dengan kode 1 bila ada yang gagal.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from app.skinmatch_ml.text.extract import LexiconMatcher  # noqa: E402
from app.skinmatch_ml.text.ingredient_safety import (  # noqa: E402
    RISK_ALL,
    analyze_ingredients,
    build_warnings,
    load_rules,
)

RULES_PATH = BACKEND / "data" / "ingredient_rules.json"
LEXICON = BACKEND / "data" / "lexicon" / "lexicon_v1.csv"
ALIAS = BACKEND / "data" / "lexicon" / "alias_v1.csv"

VALID_SKIN_TYPES = {"Normal", "Kering", "Berminyak", "Sensitif", RISK_ALL}

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    raw = json.loads(RULES_PATH.read_text(encoding="utf-8"))
    rules = load_rules(RULES_PATH)

    # ── Struktur file ─────────────────────────────────────────────────────────
    check(len(rules) >= 100, f"jumlah aturan terlalu sedikit: {len(rules)}")
    check("_meta" in raw, "_meta hilang dari file aturan")
    for name, rule in rules.items():
        check(name == name.lower(), f"key bukan huruf kecil: {name}")
        check(bool(rule.get("function")), f"function kosong: {name}")
        targets = rule.get("risk_skin_types")
        check(isinstance(targets, list), f"risk_skin_types bukan list: {name}")
        unknown = set(targets or []) - VALID_SKIN_TYPES
        check(not unknown, f"nilai skin type tidak dikenal pada {name}: {unknown}")
        if targets:
            check(bool(rule.get("risk_note")), f"aturan berisiko tanpa risk_note: {name}")
            check(bool(rule.get("source")), f"aturan berisiko tanpa source: {name}")

    # ── Semua key harus benar-benar keluar dari LexiconMatcher ────────────────
    matcher = LexiconMatcher.from_files(LEXICON, ALIAS)
    produced = set(matcher.mapping.values())
    orphan = sorted(name for name in rules if name not in produced)
    check(not orphan, f"{len(orphan)} key tidak pernah dihasilkan matcher: {orphan[:10]}")

    # ── Perilaku analisis ─────────────────────────────────────────────────────
    sample = [
        "aqua",
        "glycerin",
        "niacinamide",
        "parfum",
        "alcohol denat",
        "cetearyl alcohol",
        "methylisothiazolinone",
        "isopropyl myristate",
        "cocos nucifera (coconut) oil",
        "titanium dioxide",
        "bahan-tidak-dikenal-xyz",
    ]

    oily = analyze_ingredients(sample, "Berminyak", rules)
    oily_risky = {item["name"] for item in oily["risky"]}
    oily_safe = {item["name"] for item in oily["safe"]}

    check("cetearyl alcohol" in oily_safe, "fatty alcohol salah ditandai Perhatian")
    check("glycerin" in oily_safe, "glycerin salah ditandai Perhatian")
    check("aqua" in oily_safe, "aqua salah ditandai Perhatian")
    check("bahan-tidak-dikenal-xyz" in oily_safe, "bahan tanpa aturan tidak masuk safe")
    check("parfum" in oily_risky, "parfum tidak ditandai Perhatian untuk kulit berminyak")
    check("isopropyl myristate" in oily_risky, "isopropyl myristate tidak ditandai untuk berminyak")
    check("cocos nucifera (coconut) oil" in oily_risky, "coconut oil tidak ditandai untuk berminyak")
    check("alcohol denat" not in oily_risky, "alkohol pengering ikut ditandai untuk berminyak")
    check(
        "methylisothiazolinone" in oily_risky,
        "pengawet ALL tidak ditandai untuk kulit berminyak",
    )

    dry = analyze_ingredients(sample, "Kering", rules)
    dry_risky = {item["name"] for item in dry["risky"]}
    check("alcohol denat" in dry_risky, "alkohol pengering tidak ditandai untuk kulit kering")
    check("isopropyl myristate" not in dry_risky, "komedogenik ikut ditandai untuk kulit kering")

    sensitive = analyze_ingredients(sample, "Sensitif", rules)
    sensitive_risky = {item["name"] for item in sensitive["risky"]}
    check("parfum" in sensitive_risky, "parfum tidak ditandai untuk kulit sensitif")
    check(
        "methylisothiazolinone" in sensitive_risky,
        "pengawet ALL tidak ditandai untuk kulit sensitif",
    )

    # Semua item berisiko membawa catatan dan sumber
    for group in (oily, dry, sensitive):
        for item in group["risky"]:
            check(bool(item["risk_note"]), f"risk_note kosong: {item['name']}")
            check(bool(item["source"]), f"source kosong: {item['name']}")
            check(item["risk_level"] == "risky", f"risk_level salah: {item['name']}")
            check(" — " in item["function"], f"catatan tidak tergabung di function: {item['name']}")

    # ── Peringatan ────────────────────────────────────────────────────────────
    warnings = build_warnings(oily["risky"])
    check(len(warnings) == 1, f"harus 1 baris peringatan, dapat {len(warnings)}")
    check("perlu diperhatikan" in warnings[0], "teks peringatan tidak sesuai")
    check(build_warnings([]) == [], "build_warnings([]) harus kosong")

    # ── Uji ujung-ke-ujung pada teks OCR nyata (delimiter hilang) ─────────────
    ocr_text = (
        "INGREDIENTS AQUA GLYCERIN NIACINAMIDE CETEARYL ALCOHOL PARFUM "
        "LINALOOL ALCOHOL DENAT SODIUM LAURYL SULFATE PHENOXYETHANOL "
        "TOCOPHEROL PANTHENOL SODIUM HYALURONATE ISOPROPYL MYRISTATE "
        "DMDM HYDANTOIN CI 77891"
    )
    detected = matcher.extract(ocr_text)
    covered = [name for name in detected if name in rules]
    check(len(detected) >= 12, f"matcher hanya menemukan {len(detected)} bahan dari teks uji")
    check(
        len(covered) >= 8,
        f"hanya {len(covered)}/{len(detected)} bahan hasil OCR punya aturan",
    )
    result = analyze_ingredients(detected, "Sensitif", rules)
    names = {item["name"] for item in result["risky"]}
    for expected in ("parfum", "linalool", "alcohol denat", "sodium lauryl sulfate", "dmdm hydantoin"):
        check(expected in names, f"bahan {expected} tidak muncul sebagai Perhatian pada teks OCR")

    # ── Laporan ───────────────────────────────────────────────────────────────
    print(f"aturan          : {len(rules)}")
    print(f"bahan uji OCR   : {len(detected)} terdeteksi, {len(covered)} punya aturan")
    print(f"Perhatian (Sensitif): {len(result['risky'])}")
    if failures:
        print(f"\nGAGAL ({len(failures)}):")
        for message in failures:
            print(f"  - {message}")
        return 1
    print("\nSEMUA CEK LULUS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
