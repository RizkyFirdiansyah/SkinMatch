"""
Import produk dari CSV ke database.
Run: python -m app.import_products
"""
import csv
from pathlib import Path
from app.database import SessionLocal
from app.models.category import Category
from app.models.product import Product


def import_products_from_csv(csv_path: str = "data/products.csv"):
    db = SessionLocal()
    
    csv_file = Path(__file__).parent.parent / csv_path
    
    if not csv_file.exists():
        print(f"❌ File tidak ditemukan: {csv_file}")
        return
    
    created = 0
    skipped = 0
    errors = 0
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            try:
                # Get category
                category = db.query(Category).filter(
                    Category.slug == row['category']
                ).first()
                
                if not category:
                    print(f"⚠️  Category '{row['category']}' tidak ditemukan untuk {row['name']}")
                    errors += 1
                    continue
                
                # Check if product already exists
                exists = db.query(Product).filter(
                    Product.name == row['name'],
                    Product.brand == row['brand']
                ).first()
                
                if exists:
                    print(f"⏭️  Skipped: {row['brand']} - {row['name']} (already exists)")
                    skipped += 1
                    continue
                
                # Create product
                product = Product(
                    name=row['name'],
                    brand=row['brand'],
                    category_id=category.id,
                    ingredients_text=row['ingredients_text'],
                    bpom_number=row.get('bpom_number', None),
                    price=float(row['price']) if row.get('price') else None
                )
                
                db.add(product)
                created += 1
                print(f"✅ Created: {row['brand']} - {row['name']}")
                
            except Exception as e:
                print(f"❌ Error: {row.get('name', 'unknown')}: {str(e)}")
                errors += 1
    
    db.commit()
    db.close()
    
    print(f"\n🎉 Done!")
    print(f"   Created: {created}")
    print(f"   Skipped: {skipped}")
    print(f"   Errors: {errors}")


if __name__ == "__main__":
    import_products_from_csv()