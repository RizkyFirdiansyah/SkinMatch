"""Cek mandiri fitur nama produk (tanpa pytest).

Butuh server uji hidup di port 8011:
    .venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8011

Jalankan dari `backend/`:
    .venv/Scripts/python.exe tests/check_scan_product_name.py
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
PROBE_EMAILS = ("nameprobe_a@example.com", "nameprobe_b@example.com")
db = SessionLocal()


def purge_probe_rows() -> int:
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


def call(method: str, path: str, headers=None, json=None):
    return requests.request(method, BASE_URL + path, headers=headers, json=json, timeout=60)


def check(label: str, condition: bool, detail: object = "") -> None:
    if not condition:
        raise AssertionError(f"GAGAL: {label} {detail}".strip())
    print(f"  ok  {label}")


def register(email: str) -> tuple[int, dict]:
    response = call(
        "POST",
        "/api/auth/register",
        json={
            "name": "Name Probe",
            "email": email,
            "password": "Test12345!",
            "confirm_password": "Test12345!",
        },
    )
    assert response.status_code in (200, 201), response.text
    token = response.json()["data"]["token"]
    db.rollback()  # MySQL REPEATABLE READ: snapshot baru agar baris commit API terlihat
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
    user_a, headers_a = register(PROBE_EMAILS[0])
    user_b, headers_b = register(PROBE_EMAILS[1])
    scan_a = make_scan(user_a, "a")
    scan_b = make_scan(user_b, "b")
    print(f"user A={user_a} scan={scan_a} | user B={user_b} scan={scan_b}")

    print("\n[1] scan baru belum punya nama")
    body = call("GET", f"/api/scans/{scan_a}", headers=headers_a).json()
    check("detail product_name null", body["data"]["product_name"] is None)
    body = call("GET", "/api/scans", headers=headers_a).json()
    row = next(r for r in body["data"]["scans"] if r["scan_id"] == scan_a)
    check(
        "riwayat pakai fallback",
        row["product_name"] == f"Hasil pindai #{scan_a}",
        row["product_name"],
    )
    check("bukan 'Unknown Product'", row["product_name"] != "Unknown Product")

    print("\n[2] beri nama")
    body = call(
        "PATCH", f"/api/scans/{scan_a}", headers=headers_a, json={"product_name": "  Somethinc  Niacinamide   Serum "}
    ).json()
    check("pesan sukses", body["message"] == "Nama produk diperbarui", body["message"])
    check("spasi dirapikan", body["data"]["product_name"] == "Somethinc Niacinamide Serum", body["data"])

    print("\n[3] nama kepakai di semua respons")
    body = call("GET", f"/api/scans/{scan_a}", headers=headers_a).json()
    check("detail", body["data"]["product_name"] == "Somethinc Niacinamide Serum", body["data"].get("product_name"))
    body = call("GET", "/api/scans", headers=headers_a).json()
    row = next(r for r in body["data"]["scans"] if r["scan_id"] == scan_a)
    check("riwayat", row["product_name"] == "Somethinc Niacinamide Serum", row["product_name"])

    call("POST", f"/api/saved-products/{scan_a}", headers=headers_a).raise_for_status()
    body = call("GET", "/api/saved-products", headers=headers_a).json()
    check(
        "daftar simpanan ikut nama",
        body["data"]["saved_products"][0]["product_name"] == "Somethinc Niacinamide Serum",
        body["data"]["saved_products"][0],
    )

    print("\n[4] ubah nama + nama sama boleh dipakai scan lain")
    body = call("PATCH", f"/api/scans/{scan_a}", headers=headers_a, json={"product_name": "Serum B"}).json()
    check("ubah nama", body["data"]["product_name"] == "Serum B")
    body = call("PATCH", f"/api/scans/{scan_a}", headers=headers_a, json={"product_name": "Serum B"}).json()
    check("idempoten", body["data"]["product_name"] == "Serum B")

    print("\n[5] validasi input")
    for label, payload in (
        ("kosong", {"product_name": ""}),
        ("spasi doang", {"product_name": "   "}),
        ("151 char", {"product_name": "x" * 151}),
        ("field hilang", {}),
    ):
        response = call("PATCH", f"/api/scans/{scan_a}", headers=headers_a, json=payload)
        check(f"{label} -> 422", response.status_code == 422, response.status_code)

    body = call("PATCH", f"/api/scans/{scan_a}", headers=headers_a, json={"product_name": "x" * 150})
    check("150 char diterima", body.status_code == 200, body.status_code)

    print("\n[6] isolasi antar user")
    response = call("PATCH", f"/api/scans/{scan_b}", headers=headers_a, json={"product_name": "Curian"})
    check("scan user lain -> 404", response.status_code == 404, response.status_code)
    response = call("PATCH", "/api/scans/999999", headers=headers_a, json={"product_name": "Hantu"})
    check("scan tidak ada -> 404", response.status_code == 404, response.status_code)
    body = call("GET", f"/api/scans/{scan_b}", headers=headers_b).json()
    check("nama scan B tidak berubah", body["data"]["product_name"] is None, body["data"].get("product_name"))

    print("\n[7] auth wajib")
    response = call("PATCH", f"/api/scans/{scan_a}", json={"product_name": "Tanpa Token"})
    check("tanpa token -> 403/401", response.status_code in (401, 403), response.status_code)

    print("\nSEMUA CEK LULUS")
finally:
    removed = purge_probe_rows()
    print(f"cleanup: {removed} user probe dihapus")
    db.close()
