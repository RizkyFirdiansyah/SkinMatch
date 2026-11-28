"""Import produk dari CSV ke database.

Run:
  python -m app.import_products             # tambah produk baru saja
  python -m app.import_products --dry-run   # validasi + lihat rencana, DB tidak diubah
  python -m app.import_products --update    # produk yang sudah ada diisi/ditimpa dari CSV
"""
import argparse
import csv
from pathlib import Path

from app.database import SessionLocal
from app.models.category import Category
from app.models.product import Product

FIELDS = ("description", "ingredients_text", "image_url", "bpom_number", "price")


def clean(value):
    value = (value or "").strip()
    return value or None


def import_products_from_csv(csv_path="data/products.csv", dry_run=False, update=False):
    db = SessionLocal()
    csv_file = Path(__file__).parent.parent / csv_path

    if not csv_file.exists():
        print(f"File tidak ditemukan: {csv_file}")
        return 1

    created = updated = skipped = errors = 0

    with open(csv_file, "r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            name, brand = clean(row.get("name")), clean(row.get("brand"))
            try:
                category = db.query(Category).filter(Category.slug == clean(row.get("category"))).first()
                if not category:
                    print(f"  kategori '{row.get('category')}' tidak ada: {brand} - {name}")
                    errors += 1
                    continue

                values = {
                    "description": clean(row.get("description")),
                    "ingredients_text": clean(row.get("ingredients_text")),
                    "image_url": clean(row.get("image_url")),
                    "bpom_number": clean(row.get("bpom_number")),
                    "price": float(row["price"]) if clean(row.get("price")) else None,
                }
                if not values["ingredients_text"]:
                    print(f"  ingredients_text kosong: {brand} - {name}")
                    errors += 1
                    continue

                product = db.query(Product).filter(Product.name == name, Product.brand == brand).first()
                if product and not update:
                    skipped += 1
                    continue

                if product:
                    for field, value in values.items():
                        if value is not None:
                            setattr(product, field, value)
                    product.category_id = category.id
                    updated += 1
                    print(f"  update: {brand} - {name}")
                else:
                    db.add(Product(name=name, brand=brand, category_id=category.id, **values))
                    created += 1
                    print(f"  baru:   {brand} - {name}")

            except Exception as exc:
                print(f"  error: {brand} - {name}: {exc}")
                errors += 1

    if dry_run:
        db.rollback()
    else:
        db.commit()
    db.close()

    print(f"\n{'DRY RUN (tidak disimpan)' if dry_run else 'Selesai'}: "
          f"baru {created}, update {updated}, skip {skipped}, error {errors}")
    return 1 if errors else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/products.csv")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--update", action="store_true")
    args = ap.parse_args()
    raise SystemExit(import_products_from_csv(args.csv, args.dry_run, args.update))
