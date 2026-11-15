"""
Seed data untuk tabel categories.
Run: python -m app.seed_categories
"""
from app.database import SessionLocal
from app.models.category import Category


def seed_categories():
    db = SessionLocal()
    
    categories_data = [
        {"name": "Serum", "slug": "serum"},
        {"name": "Moisturizer", "slug": "moisturizer"},
        {"name": "Sunscreen", "slug": "sunscreen"},
        {"name": "Cleanser", "slug": "cleanser"},
        {"name": "Toner", "slug": "toner"},
        {"name": "Face Wash", "slug": "face-wash"},
        {"name": "Sleeping Mask", "slug": "sleeping-mask"},
        {"name": "Sheet Mask", "slug": "sheet-mask"},
        {"name": "Eye Cream", "slug": "eye-cream"},
        {"name": "Lip Care", "slug": "lip-care"},
    ]
    
    created = 0
    skipped = 0
    
    for cat_data in categories_data:
        # Check if exists
        exists = db.query(Category).filter(Category.slug == cat_data["slug"]).first()
        if not exists:
            category = Category(**cat_data)
            db.add(category)
            created += 1
            print(f"✅ Created: {cat_data['name']}")
        else:
            skipped += 1
            print(f"⏭️  Skipped: {cat_data['name']} (already exists)")
    
    db.commit()
    db.close()
    
    print(f"\n🎉 Done! Created: {created}, Skipped: {skipped}")


if __name__ == "__main__":
    seed_categories()