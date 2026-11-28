"""Validasi data/products.csv sebelum diimpor ke database.

Run: python tests/check_product_catalog.py [--csv data/products.csv]
Keluar dengan kode 1 kalau ada error.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import SessionLocal  # noqa: E402
from app.models.category import Category  # noqa: E402

HEADER = ["name", "brand", "category", "description", "ingredients_text",
          "image_url", "bpom_number", "price"]
BPOM = re.compile(r"^(NA|NC|NK|NKE|NKIT)\d{6,}$", re.I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/products.csv")
    args = ap.parse_args()

    path = Path(__file__).resolve().parent.parent / args.csv
    if not path.exists():
        print(f"FAIL file tidak ada: {path}")
        return 1

    db = SessionLocal()
    slugs = {c.slug for c in db.query(Category).all()}
    db.close()

    errors, seen, rows = [], set(), 0
    with open(path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != HEADER:
            print(f"FAIL header harus: {','.join(HEADER)}")
            print(f"     header file: {','.join(reader.fieldnames or [])}")
            return 1

        for i, row in enumerate(reader, start=2):
            rows += 1
            name = (row["name"] or "").strip()
            brand = (row["brand"] or "").strip()
            key = (name.lower(), brand.lower())

            if not name or not brand:
                errors.append(f"baris {i}: name/brand kosong")
            if key in seen:
                errors.append(f"baris {i}: duplikat {brand} - {name}")
            seen.add(key)

            if row["category"] not in slugs:
                errors.append(f"baris {i}: kategori '{row['category']}' tidak ada di DB")
            if len([x for x in (row["ingredients_text"] or "").split(",") if x.strip()]) < 3:
                errors.append(f"baris {i}: ingredients_text kurang dari 3 bahan ({brand} - {name})")
            bpom = (row["bpom_number"] or "").strip()
            if bpom and not BPOM.match(bpom):
                errors.append(f"baris {i}: bpom_number '{bpom}' tidak sesuai pola NIE")
            price = (row["price"] or "").strip()
            if price:
                try:
                    if float(price) <= 0:
                        errors.append(f"baris {i}: price harus > 0")
                except ValueError:
                    errors.append(f"baris {i}: price '{price}' bukan angka")

    for err in errors:
        print(" ", err)
    print(f"\n{rows} baris | {len(errors)} error | kategori DB: {len(slugs)}")
    print("LULUS" if not errors else "GAGAL")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
