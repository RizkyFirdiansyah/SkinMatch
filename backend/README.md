# SkinMatch Backend API

Backend REST API untuk aplikasi SkinMatch - analisis kecocokan produk kosmetik berdasarkan tipe kulit.

## Tech Stack

- **Framework:** FastAPI 0.115.0
- **Database:** MySQL 8.0+
- **ORM:** SQLAlchemy 2.0+ (terpasang 2.1.8)
- **Authentication:** JWT (`python-jose`)
- **Password Hashing:** bcrypt

## Setup

### 1. Install Dependencies

```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 2. Configure Environment

Buat file `.env` di folder `backend/`:

```env
DATABASE_URL=mysql+pymysql://root:your-mysql-password@localhost:3306/skinmatch
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_DAYS=30
```

> `SECRET_KEY` bisa dibuat dengan `python -c "import secrets; print(secrets.token_hex(32))"`.

### 3. Create Database

```bash
mysql -u root -p
```

```sql
CREATE DATABASE skinmatch CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. Create Tables

```bash
python
>>> from app.database import engine, Base
>>> from app.models import user, scan
>>> Base.metadata.create_all(bind=engine)
>>> exit()
```

### 5. Run Server

```bash
uvicorn app.main:app --reload
```

Buka http://localhost:8000/docs untuk Swagger UI.

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register user baru (auto-login)
- `POST /api/auth/login` - Login user

### Profile
- `GET /api/profile` - Get user profile (require auth)
- `PUT /api/profile` - Update skin type (require auth)

### Scans
- `POST /api/scans` - Upload & analyze product image (require auth)
- `GET /api/scans` - Get scan history (require auth)
- `GET /api/scans/{scan_id}` - Get scan detail (require auth)

### Utility
- `GET /health` - Health check (termasuk cek koneksi database)
- `GET /` - Root info

## Response Format

Semua endpoint mengembalikan envelope yang konsisten:

```json
{
  "status": "success",
  "message": null,
  "data": { }
}
```

Saat error, `status` bernilai `"error"` dan `message` berisi keterangan.

## Authentication

Semua protected endpoint memerlukan JWT token di header Authorization:

```
Authorization: Bearer <token>
```

Token valid selama 30 hari.

### Register / Login

```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

Response `data` berisi:

```json
{
  "user_id": 1,
  "name": "Test User",
  "email": "test@example.com",
  "skin_type": "Normal",
  "token": "<jwt>",
  "profile_completed": true
}
```

> Nama field token adalah **`token`**, bukan `access_token`.

### Upload Scan

Field multipart wajib bernama **`image`**:

```bash
curl -X POST http://localhost:8000/api/scans \
  -H "Authorization: Bearer <token>" \
  -F "image=@produk.jpg"
```

## Nilai `skin_type`

`Normal`, `Kering`, `Berminyak`, `Sensitif`

## Test Account

```
Email: test@example.com
Password: password123
Skin Type: Normal
```

## Current Status

**✅ Working:**
- Authentication (register, login, JWT)
- Profile management (get, update skin type)
- Scan upload & history (dummy OCR/ML response)

**⏳ TODO:**
- Week 6: Integrate Risky's OCR module
- Week 7: Integrate Rizky's ML model
- Week 8: Review endpoints
- Week 9-10: Search & Recommendations

## Development

Run with auto-reload:

```bash
uvicorn app.main:app --reload
```

Access Swagger docs:

```
http://localhost:8000/docs
```

## Catatan Implementasi

- `image_url` pada response scan berupa **path relatif** (`/uploads/scans/<file>.jpg`). Static file serving belum di-mount, jadi file perlu diakses langsung dari disk atau lewat endpoint terpisah.
- Upload dibatasi maksimal **2MB**.
- Setiap model baru wajib didaftarkan di `app/models/__init__.py`, jika tidak akan muncul `KeyError` saat mapper SQLAlchemy diinisialisasi.

## Team

- **Backend Engineer:** Radita Yoga Anugrah
- **Mobile Engineer:** Raihan Daffa Izzuddin
- **Data & OCR Engineer:** Risky Adi Prasetya
- **ML Engineer:** Muhammad Rizky Firdiansyah
- **QA Lead:** Hafif Nurrahmad

## Repository

https://github.com/RizkyFirdiansyah/SkinMatch
