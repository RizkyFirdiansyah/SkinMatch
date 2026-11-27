"""Tag keamanan per bahan: `Aman` vs `Perhatian`, berbasis tabel aturan.

Kenapa bukan model ML: `models/model.joblib` dilatih pada label marketing level
produk (`who_is_it_good_for`) dan memberi bobot negatif pada bahan netral seperti
`aqua` dan `glycerin`. Model itu tidak bisa dipakai untuk menilai keamanan satu
bahan. Aturan di sini deterministik dan bisa diaudit per baris.

Sumber aturan: `data/ingredient_rules.json` (lihat `_meta.sources`).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

RISK_ALL = "ALL"

DEFAULT_SAFE_FUNCTION = "Bahan terdaftar di lexicon INCI"
RISKY_SEPARATOR = " — "


def load_rules(path: str | Path) -> dict[str, dict[str, Any]]:
    """Muat tabel aturan. Key `_meta` dibuang, sisanya {canonical: rule}."""
    with Path(path).open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    rules = payload.get("rules")
    if not isinstance(rules, dict):
        raise ValueError(f"Tabel aturan tidak valid: {path}")
    return {str(k).lower(): v for k, v in rules.items()}


def _applies(rule: dict[str, Any], skin_type: str | None) -> bool:
    targets = rule.get("risk_skin_types") or []
    if not targets:
        return False
    if RISK_ALL in targets:
        return True
    return skin_type in targets


def analyze_ingredients(
    ingredients: Iterable[str],
    skin_type: str | None,
    rules: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Pisahkan bahan jadi `safe` dan `risky` untuk tipe kulit tertentu.

    Bahan tanpa aturan masuk `safe` dengan keterangan netral: daftar aturan hanya
    mencakup bahan berisiko, bukan seluruh 21 ribu kanonik lexicon.
    """
    safe: list[dict[str, Any]] = []
    risky: list[dict[str, Any]] = []

    for name in ingredients:
        rule = rules.get(name.strip().lower())
        if rule and _applies(rule, skin_type):
            function = rule.get("function") or DEFAULT_SAFE_FUNCTION
            note = rule.get("risk_note") or ""
            risky.append(
                {
                    "name": name,
                    "function": f"{function}{RISKY_SEPARATOR}{note}".strip(RISKY_SEPARATOR),
                    "risk_level": "risky",
                    "risk_skin_types": list(rule.get("risk_skin_types") or []),
                    "risk_note": note,
                    "source": rule.get("source"),
                }
            )
            continue

        safe.append(
            {
                "name": name,
                "function": (rule or {}).get("function") or DEFAULT_SAFE_FUNCTION,
                "risk_level": "safe",
            }
        )

    return {"safe": safe, "risky": risky, "unknown": []}


def build_warnings(risky: list[dict[str, Any]], limit: int = 5) -> list[str]:
    """Ringkasan peringatan dari bahan `Perhatian`, urut kemunculan."""
    if not risky:
        return []
    names = ", ".join(item["name"] for item in risky[:limit])
    extra = len(risky) - limit
    suffix = f" (+{extra} bahan lain)" if extra > 0 else ""
    return [f"Bahan yang perlu diperhatikan untuk tipe kulit Anda: {names}{suffix}."]
