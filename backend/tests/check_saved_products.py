"""Cek mandiri fitur simpan produk (tanpa pytest).

Butuh server uji hidup di port 8011:
    .venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8011

Jalankan dari `backend/`:
    .venv/Scripts/python.exe tests/check_saved_products.py

Membuat 2 user + 3 scan sementara, menguji endpoint lewat HTTP,
lalu menghapus semua barisnya lagi.
"""

import os
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database import SessionLocal
from app.models.saved_product import SavedProduct
from app.models.scan import Scan
from app.models.user import User

BASE_URL = os.environ.get("SKINMATCH_TEST_URL", "http://127.0.0.1:8011")


class Client:
    """Shim tipis di atas `requests`: TestClient starlette bentrok dengan httpx 0.28."""

    def _call(self, method: str, path: str, headers=None, json=None):
        return requests.request(
            method, BASE_URL + path, headers=headers, json=json, timeout=60
        )

    def get(self, path, headers=None):
        return self._call("GET", path, headers=headers)

    def post(self, path, headers=None, json=None):
        return self._call("POST", path, headers=headers, json=json)

    def delete(self, path, headers=None):
        return self._call("DELETE", path, headers=headers)


client = Client()
db = SessionLocal()
PROBE_EMAILS = ("savedprobe_a@example.com", "savedprobe_b@example.com")


def purge_probe_rows() -> int:
    """Hapus sisa baris probe dari run sebelumnya (cleanup selalu jalan)."""
    db.rollback()
    users = db.query(User).filter(User.email.in_(PROBE_EMAILS)).all()
    ids = [user.id for user in users]
    if ids:
        db.query(SavedProduct).filter(SavedProduct.user_id.in_(ids)).delete(
            synchronize_session=False
        )
        db.query(Scan).filter(Scan.user_id.in_(ids)).delete(synchronize_session=False)
        db.query(User).filter(User.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
    return len(ids)


def check(label: str, condition: bool, detail: object = "") -> None:
    if not condition:
        raise AssertionError(f"GAGAL: {label} {detail}".strip())
    print(f"  ok  {label}")


def register(email: str) -> tuple[int, dict]:
    response = client.post(
        "/api/auth/register",
        json={
            "name": "Saved Probe",
            "email": email,
            "password": "Test12345!",
            "confirm_password": "Test12345!",
        },
    )
    assert response.status_code in (200, 201), response.text
    token = response.json()["data"]["token"]
    db.rollback()  # MySQL REPEATABLE READ: buka snapshot baru agar baris commit API terlihat
    user = db.query(User).filter(User.email == email).first()
    assert user is not None, f"user {email} tidak ketemu setelah register"
    return user.id, {"Authorization": f"Bearer {token}"}


def make_scan(user_id: int, tag: str) -> int:
    scan = Scan(
        user_id=user_id,
        image_path=f"uploads/probe_{tag}.png",
        classification_result="Cocok",
        classification_code=1,
        confidence=87.5,
        classification_details={"explanation": "probe"},
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)
    return scan.id


try:
    stale = purge_probe_rows()
    if stale:
        print(f"purge: {stale} user probe sisa run sebelumnya dihapus")
    user_a, headers_a = register("savedprobe_a@example.com")
    user_b, headers_b = register("savedprobe_b@example.com")
    scan_a1 = make_scan(user_a, "a1")
    scan_a2 = make_scan(user_a, "a2")
    scan_b1 = make_scan(user_b, "b1")
    print(f"user A={user_a} scans={scan_a1},{scan_a2} | user B={user_b} scan={scan_b1}")

    print("\n[1] daftar awal kosong")
    body = client.get("/api/saved-products", headers=headers_a).json()
    check("total_items == 0", body["data"]["total_items"] == 0)

    print("\n[2] simpan produk")
    body = client.post(f"/api/saved-products/{scan_a1}", headers=headers_a).json()
    saved_id = body["data"]["saved_id"]
    check("pesan 'Produk disimpan'", body["message"] == "Produk disimpan", body["message"])
    check("saved_id terisi", isinstance(saved_id, int) and saved_id > 0)

    print("\n[3] simpan ulang idempoten")
    body = client.post(f"/api/saved-products/{scan_a1}", headers=headers_a).json()
    check("saved_id sama", body["data"]["saved_id"] == saved_id)
    check("pesan 'sudah tersimpan'", body["message"] == "Produk sudah tersimpan", body["message"])
    db.rollback()  # snapshot baru: hitung baris yang baru di-commit API
    check(
        "baris DB tetap 1",
        db.query(SavedProduct).filter(SavedProduct.user_id == user_a).count() == 1,
    )

    print("\n[4] daftar simpanan")
    body = client.get("/api/saved-products", headers=headers_a).json()
    items = body["data"]["saved_products"]
    check("total_items == 1", body["data"]["total_items"] == 1)
    item = items[0]
    for key in (
        "saved_id",
        "saved_at",
        "scan_id",
        "timestamp",
        "product_name",
        "brand",
        "result",
        "confidence",
        "has_review",
        "thumbnail_url",
    ):
        check(f"key {key} ada", key in item, sorted(item))
    check("scan_id cocok", item["scan_id"] == scan_a1)
    check(
        "product_name fallback",
        item["product_name"] == f"Hasil pindai #{scan_a1}",
        item["product_name"],
    )
    check("result terbawa", item["result"] == "Cocok")

    print("\n[5] is_saved di riwayat scan")
    body = client.get("/api/scans", headers=headers_a).json()
    flags = {row["scan_id"]: row["is_saved"] for row in body["data"]["scans"]}
    check("scan tersimpan is_saved=True", flags[scan_a1] is True, flags)
    check("scan lain is_saved=False", flags[scan_a2] is False, flags)

    print("\n[6] is_saved di detail scan")
    body = client.get(f"/api/scans/{scan_a1}", headers=headers_a).json()
    check("detail is_saved=True", body["data"]["is_saved"] is True)
    body = client.get(f"/api/scans/{scan_a2}", headers=headers_a).json()
    check("detail scan lain is_saved=False", body["data"]["is_saved"] is False)

    print("\n[7] isolasi antar user")
    response = client.post(f"/api/saved-products/{scan_b1}", headers=headers_a)
    check("scan user lain -> 404", response.status_code == 404, response.status_code)
    response = client.post("/api/saved-products/999999", headers=headers_a)
    check("scan tidak ada -> 404", response.status_code == 404, response.status_code)
    body = client.get("/api/saved-products", headers=headers_b).json()
    check("user B belum punya simpanan", body["data"]["total_items"] == 0)

    print("\n[8] hapus dari simpanan")
    client.post(f"/api/saved-products/{scan_a2}", headers=headers_a).raise_for_status()
    response = client.delete(f"/api/saved-products/{scan_a1}", headers=headers_a)
    check("hapus -> 200", response.status_code == 200, response.status_code)
    body = client.get("/api/saved-products", headers=headers_a).json()
    check("sisa 1 simpanan", body["data"]["total_items"] == 1)
    check("yang tersisa scan_a2", body["data"]["saved_products"][0]["scan_id"] == scan_a2)
    response = client.delete(f"/api/saved-products/{scan_a1}", headers=headers_a)
    check("hapus ulang -> 404", response.status_code == 404, response.status_code)

    print("\n[9] auth wajib")
    check(
        "tanpa token -> 403/401",
        client.get("/api/saved-products").status_code in (401, 403),
    )

    print("\nSEMUA CEK LULUS")
finally:
    removed = purge_probe_rows()
    print(f"cleanup: {removed} user probe dihapus")
    db.close()
