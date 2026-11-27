# SkinMatch Backend API

Backend REST API untuk aplikasi SkinMatch — analisis kecocokan produk kosmetik berdasarkan tipe kulit pengguna. Repo ini berisi backend FastAPI (`backend/`) dan aplikasi Flutter (`skinmatch/`).

Panduan ini ditulis untuk anggota tim yang baru pertama kali menjalankan proyek. Semua perintah memakai **PowerShell di Windows**; padanan bash ditulis di catatan kecil bila berbeda.

---

## 1. Prasyarat

| Kebutuhan | Versi | Catatan |
|---|---|---|
| Python | **3.12.x** | Jangan 3.13/3.14 — wheel `paddlepaddle` belum tersedia |
| MySQL | 8.0+ | XAMPP/Laragon boleh, asal MySQL 8 |
| Git | terbaru | |
| Flutter SDK | **3.47+** (Dart 3.13.2+) | sesuai `skinmatch/pubspec.yaml`; hanya kalau mau menjalankan aplikasi mobile |
| Android Studio / VS Code | — | plus emulator atau HP Android |

Cek cepat:

```powershell
py -3.12 --version
mysql --version
flutter --version
git --version
```

---

## 2. Clone Repository

```powershell
git clone https://github.com/RizkyFirdiansyah/SkinMatch.git
cd SkinMatch
git checkout devel
git pull
```

Semua pekerjaan fitur dimulai dari `devel`. Jangan kerja langsung di `devel` atau `main`.

---

## 3. Setup Backend

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Catatan:

- Instalasi pertama lama (5–15 menit) karena `paddlepaddle` + `paddleocr` berukuran besar (± 500 MB). Jangan dihentikan di tengah jalan.
- Kalau PowerShell menolak aktivasi venv (`running scripts is disabled`), jalankan sekali:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```
- Setelah aktif, prompt berubah jadi `(.venv)`. Semua perintah berikutnya **wajib** dijalankan dari folder `backend/` dan memakai venv ini — `python` global tidak punya dependency proyek.

---

## 4. Konfigurasi `.env`

```powershell
Copy-Item .env.example .env
notepad .env
```

Isi minimal:

```env
DATABASE_URL=mysql+pymysql://root:PASSWORD_KAMU@localhost:3306/skinmatch
SECRET_KEY=hasil-generate-di-bawah
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_DAYS=30
```

Generate `SECRET_KEY`:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

- Kalau password MySQL mengandung `@`, `:`, atau `/`, encode dulu (contoh `@` → `%40`).
- `.env` **tidak boleh** di-commit — sudah masuk `.gitignore`.
- Tanpa `.env`, server gagal start dengan `ValidationError: DATABASE_URL Field required`.

---

## 5. Siapkan Database

Buat database (sekali saja):

```sql
CREATE DATABASE skinmatch CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Lewat PowerShell:

```powershell
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS skinmatch CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Buat/update semua tabel dengan Alembic:

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m alembic current
```

Output `alembic current` yang benar di branch `devel` terbaru:

```
20261127_scan_product_name (head)
```

**Jangan** memakai `Base.metadata.create_all()` — tabel jadi tidak punya riwayat migrasi dan Alembic akan error di kemudian hari.

Setiap kali habis `git pull` dan ada file baru di `alembic/versions/`, ulangi `alembic upgrade head`.

<details>
<summary>Kalau muncul <code>Data too long for column 'version_num'</code></summary>

Database lama punya kolom `alembic_version.version_num VARCHAR(32)`, sedangkan revision ID sekarang lebih panjang:

```sql
ALTER TABLE alembic_version MODIFY version_num VARCHAR(64);
```

lalu samakan penanda versinya:

```powershell
.\.venv\Scripts\python.exe -m alembic stamp --purge head
```
</details>

---

## 6. Jalankan Server

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- `--host 0.0.0.0` **wajib** kalau aplikasi mau diakses dari HP fisik. Dengan `127.0.0.1`, HP tidak bisa connect.
- Swagger UI: <http://localhost:8000/docs>
- Health check: <http://localhost:8000/health> → `{"status":"healthy","database":"connected"}`
- Scan pertama lambat (1–3 menit) karena memuat model OCR + klasifikasi. Scan berikutnya cepat. Ini normal, bukan hang.
- Model OCR diunduh saat pertama kali dipakai — butuh internet sekali saja.

---

## 7. Menjalankan Aplikasi Flutter (Emulator vs HP)

Backend harus sudah jalan sebelum aplikasi dibuka.

```powershell
cd ..\skinmatch
flutter pub get
flutter devices
```

### Perbedaan utama

| | **Emulator Android** | **HP fisik** |
|---|---|---|
| Alamat backend | `http://10.0.2.2:8000` (default di kode) | `http://<IP-LAN-laptop>:8000` |
| Perlu `--dart-define`? | Tidak | **Ya** |
| Jaringan | otomatis, satu mesin | HP dan laptop harus di Wi-Fi yang sama |
| Kamera | terbatas / tanpa kamera virtual | penuh |
| Kecepatan | lebih lambat (virtualisasi) | lebih cepat |

Alamat default diambil dari `skinmatch/lib/core/network/api_client.dart`:

```dart
if (kIsWeb) return 'http://localhost:8000';
return switch (defaultTargetPlatform) {
  TargetPlatform.android => 'http://10.0.2.2:8000',  // emulator
  _ => 'http://localhost:8000',
};
```

`10.0.2.2` adalah alias khusus emulator Android untuk `localhost` komputer host. Di HP fisik alamat itu **tidak ada**, jadi harus dioverride.

### A. Emulator

```powershell
flutter emulators                      # lihat daftar emulator
flutter emulators --launch Pixel_7_API_34
flutter run
```

Tidak perlu setting tambahan — `10.0.2.2` sudah otomatis.

### B. HP fisik (Wi-Fi)

1. Cari IP laptop:
   ```powershell
   ipconfig
   ```
   Pakai baris **IPv4 Address** pada adapter Wi-Fi, contoh `192.168.1.10`.
2. Pastikan backend jalan dengan `--host 0.0.0.0`.
3. Izinkan port 8000 di Windows Firewall (sekali saja, butuh PowerShell **Administrator**):
   ```powershell
   New-NetFirewallRule -DisplayName "SkinMatch API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
   ```
4. Tes dari browser HP: buka `http://192.168.1.10:8000/health`. Harus muncul JSON. Kalau gagal, jangan lanjut — masalahnya di jaringan/firewall, bukan di aplikasi.
5. Jalankan aplikasi:
   ```powershell
   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
   ```

### C. HP fisik lewat kabel USB (tanpa Wi-Fi)

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

`adb reverse` meneruskan port 8000 HP ke laptop, jadi `localhost` di HP menunjuk ke backend. Harus diulang setiap HP dicabut-pasang.

### Catatan

- Tanpa `--dart-define`, aplikasi di HP fisik akan mencoba `10.0.2.2` dan gagal dengan error koneksi.
- Kamera & torch tidak bisa diuji di emulator tanpa kamera virtual — pakai HP.
- Setelah mengganti alamat, lakukan **hot restart** (bukan hot reload), karena `baseUrl` dibaca sekali saat client dibuat.

---

## 8. Coba Alur Lengkap dengan curl

Di PowerShell tulis `curl.exe` (bukan `curl`) karena `curl` adalah alias `Invoke-WebRequest`.

```powershell
# 1. Register (langsung dapat token)
curl.exe -X POST http://localhost:8000/api/auth/register `
  -H "Content-Type: application/json" `
  -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"password\":\"password123\",\"confirm_password\":\"password123\"}'

# 2. Set tipe kulit  (ganti TOKEN)
curl.exe -X PUT http://localhost:8000/api/profile `
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" `
  -d '{\"skin_type\":\"Sensitif\"}'

# 3. Upload gambar komposisi
curl.exe -X POST http://localhost:8000/api/scans `
  -H "Authorization: Bearer TOKEN" -F "image=@produk.jpg"

# 4. Beri nama produk pada scan tersebut
curl.exe -X PATCH http://localhost:8000/api/scans/1 `
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" `
  -d '{\"product_name\":\"Somethinc Niacinamide Serum\"}'

# 5. Simpan produk
curl.exe -X POST http://localhost:8000/api/saved-products/1 -H "Authorization: Bearer TOKEN"

# 6. Lihat daftar produk tersimpan
curl.exe http://localhost:8000/api/saved-products -H "Authorization: Bearer TOKEN"
```

---

## 9. Daftar Endpoint

| Method | Path | Auth | Keterangan |
|---|---|---|---|
| POST | `/api/auth/register` | — | Daftar, langsung dapat token |
| POST | `/api/auth/login` | — | Login |
| GET | `/api/profile` | ✅ | Profil + tipe kulit |
| PUT | `/api/profile` | ✅ | Update `skin_type`, opsional `age_range`, `biological_sex` |
| POST | `/api/scans` | ✅ | Upload + analisis gambar (multipart, field `image`, maks 2 MB) |
| GET | `/api/scans` | ✅ | Riwayat scan |
| GET | `/api/scans/{scan_id}` | ✅ | Detail scan |
| PATCH | `/api/scans/{scan_id}` | ✅ | Beri/ubah `product_name` (1–150 karakter) |
| GET | `/api/saved-products` | ✅ | Daftar produk tersimpan |
| POST | `/api/saved-products/{scan_id}` | ✅ | Simpan produk (idempoten) |
| DELETE | `/api/saved-products/{scan_id}` | ✅ | Hapus dari simpanan |
| GET | `/api/search/products` | — | Cari produk katalog |
| GET | `/api/search/products/{product_id}` | — | Detail produk katalog |
| GET | `/api/search/categories` | — | Daftar kategori |
| GET | `/api/search/brands` | — | Daftar brand |
| GET | `/health` | — | Status server + database |
| GET | `/` | — | Info API |

Semua respons memakai envelope:

```json
{ "status": "success", "message": null, "data": { } }
```

Token dikirim sebagai `Authorization: Bearer <token>` dan berlaku 30 hari. Nama field token pada respons login/register adalah **`token`**, bukan `access_token`.

Nilai `skin_type` yang valid: `Normal`, `Kering`, `Berminyak`, `Sensitif`.

Gambar scan diakses lewat `http://localhost:8000/uploads/scans/<file>.jpg` (folder `uploads/` di-mount sebagai static file).

---

## 10. Skrip Pemeriksaan (tanpa pytest)

Semua di folder `backend/tests/`, dijalankan dari `backend/` dengan venv aktif.

```powershell
# Tidak butuh server
.\.venv\Scripts\python.exe tests\check_ingredient_safety.py

# Dua skrip berikut butuh server uji di port 8011 (bukan 8000, supaya tidak bentrok dengan server dev)
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8011
```

Di terminal lain:

```powershell
.\.venv\Scripts\python.exe tests\check_saved_products.py
.\.venv\Scripts\python.exe tests\check_scan_product_name.py
```

Keduanya membuat user + scan sementara lalu menghapusnya sendiri di akhir. Kalau server uji tidak di port 8011:

```powershell
$env:SKINMATCH_TEST_URL = "http://127.0.0.1:8011"
```

---

## 11. Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `ModuleNotFoundError: No module named 'app'` | jalan dari folder salah | `cd backend` dulu |
| `ValidationError ... DATABASE_URL Field required` | `.env` tidak ada / salah folder | buat `backend/.env` |
| `Access denied for user 'root'@'localhost'` | password di `.env` salah | perbaiki `DATABASE_URL` |
| `Can't connect to MySQL server` | service MySQL mati | start MySQL (XAMPP/Laragon/services.msc) |
| `Data too long for column 'version_num'` | DB lama `VARCHAR(32)` | lihat bagian 5 |
| `Multiple head revisions are present` | dua migration bercabang | `alembic heads`, lalu `alembic merge` atau samakan `down_revision` |
| `[Errno 10048] address already in use` | port 8000 dipakai | `netstat -ano \| findstr :8000` lalu `taskkill /PID <pid> /F` |
| Scan pertama lama / timeout | model OCR + klasifikasi dimuat | tunggu 1–3 menit, jangan kirim ulang |
| `400 Ukuran file terlalu besar` | gambar > 2 MB | kompres dulu; aplikasi sudah kompres otomatis |
| HP tidak bisa connect, emulator bisa | `--host 127.0.0.1` atau firewall | jalankan `--host 0.0.0.0`, izinkan port 8000 |
| `401 Token tidak valid atau sudah expired` | token kedaluwarsa (30 hari) / `SECRET_KEY` berubah | login ulang |
| `pip install` gagal di `paddlepaddle` | Python 3.13/3.14 | pakai `py -3.12 -m venv .venv` |

---

## 12. Alur Git: Commit & Push

Aturan main:

- Branch fitur selalu dari `devel`; PR selalu ke `devel`.
- Jangan pernah push langsung ke `main` atau `devel`.
- Jangan commit: `.env`, `.venv/`, `uploads/`, `build/`, dan file generated Flutter (`skinmatch/{android,ios,linux,macos,windows}/...generated_plugin*`).

### Mulai fitur baru

```powershell
git checkout devel
git pull
git checkout -b feat/nama-fitur
```

Penamaan branch: `feat/...` untuk fitur, `fix/...` untuk perbaikan, `docs/...` untuk dokumentasi.

### Cek lalu commit

```powershell
git status                       # lihat file berubah
git diff                         # lihat isi perubahan
git add backend/app/api/scans.py backend/tests/check_scan_product_name.py
git status                       # pastikan hanya file yang dimaksud yang staged
git commit -m "feat: add product name to scans"
```

Commit per satu topik. Jangan campur backend, Flutter, dan dokumentasi dalam satu commit kalau tidak berhubungan.

Format pesan:

```
feat: tambah endpoint simpan produk
fix: perbaiki validasi nama produk kosong
docs: update panduan instalasi backend
refactor: pisahkan aturan bahan ke JSON
test: tambah skrip cek nama produk
```

Butuh detail? Tambah baris kedua:

```powershell
git commit -m "feat: add saved products (save/unsave/list)" -m "- Add saved_products table + model
- Add GET/POST/DELETE /api/saved-products
- Add is_saved flag to scan responses"
```

### Push dan buat PR

```powershell
git push -u origin feat/nama-fitur
```

Lalu buka GitHub → **Compare & pull request** → base `devel` → isi judul & deskripsi → Create.

Setelah PR di-merge:

```powershell
git checkout devel
git pull
git branch -d feat/nama-fitur
```

### Setelah pull, wajib cek migrasi

```powershell
cd backend
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic upgrade head
```

Kalau ada migration baru yang belum dijalankan, endpoint akan error `Unknown column ...`.

---

## 13. Struktur Folder

```
backend/
├── alembic/versions/        # riwayat migrasi database
├── app/
│   ├── api/                 # endpoint: auth, profile, scans, saved_products, search
│   ├── models/              # tabel SQLAlchemy
│   ├── schemas/             # skema request/response
│   ├── services/            # logika auth
│   ├── skinmatch_ml/        # OCR, lexicon, aturan keamanan bahan, model klasifikasi
│   ├── config.py            # pembacaan .env
│   ├── database.py          # koneksi & session
│   └── main.py              # inisialisasi FastAPI + router
├── data/                    # lexicon, aturan bahan, dataset katalog
├── models/                  # model.joblib + labels.json
├── tests/                   # skrip cek mandiri (bukan pytest)
├── uploads/scans/           # gambar hasil upload (tidak di-commit)
└── requirements.txt
```

---

## 14. Catatan Implementasi

- Setiap model baru wajib didaftarkan di `app/models/__init__.py`, kalau tidak SQLAlchemy melempar `KeyError` saat mapper diinisialisasi.
- Revision ID Alembic maksimal **32 karakter** — sebagian database anggota tim masih memakai `VARCHAR(32)`.
- `ocr_confidence` adalah rata-rata skor OCR; `confidence` adalah probabilitas model klasifikasi. Keduanya **bukan** akurasi klinis.
- Aturan keamanan bahan bersifat deterministik (`data/ingredient_rules.json`), bukan keluaran model ML.
- `data/products.csv` hanya dipakai untuk impor katalog; daftar bahan untuk OCR berasal dari `data/lexicon/lexicon_v1.csv` + `alias_v1.csv`.

---

## 15. Tim

- **Backend Engineer:** Radita Yoga Anugrah
- **Mobile Engineer:** Raihan Daffa Izzuddin
- **Data & OCR Engineer:** Risky Adi Prasetya
- **ML Engineer:** Muhammad Rizky Firdiansyah
- **QA Lead:** Hafif Nurrahmad

Repository: <https://github.com/RizkyFirdiansyah/SkinMatch>
