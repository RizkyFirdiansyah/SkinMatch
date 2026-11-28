"""Isi kolom image_url di data/products.csv dari situs resmi brand.

Sumber yang dipakai (tidak perlu isi manual satu-satu):
  * Shopify  : /products.json -> judul + gambar (Skintific, Glad2Glow, Skin1004)
  * Sitemap  : URL produk dari sitemap, lalu ambil gambar dari halaman produk
               (Facetology, Avoskin, Azarine, Somethinc)

Gambar diunduh ke backend/uploads/products/ dan image_url diisi path lokal
(/uploads/products/...), jadi tidak bergantung hotlink CDN brand.
Produk yang tidak ketemu dibiarkan kosong dan dilaporkan.

Run:
  python scripts/fetch_product_images.py --dry-run
  python scripts/fetch_product_images.py
"""
import argparse
import csv
import html as H
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG_DIR = ROOT / "uploads" / "products"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0 Safari/537.36")

SHOPIFY = {
    "Skintific": "https://skintific.com",
    "Glad2Glow": "https://glad2glow.com",
    "Skin1004": "https://skin1004.com",
}
# brand: (sitemap, pola URL produk, cara ambil gambar)
SITEMAP = {
    "Facetology": ("https://facetology.id/product-sitemap.xml", r"/product/[^/]+/?$", "og"),
    "Avoskin": ("https://www.avoskinbeauty.com/sitemap-0.xml", r"/product/[^/]+$", "og"),
    "Azarine": ("https://azarinecosmetic.com/sitemap.xml", r"/product/[^/]+$", "flitts"),
    "Somethinc": ("https://www.somethinc.com/sitemap-product.xml", r"/product/detail/[^/]+$", "somethinc"),
}
STOP = {"dan", "the", "for", "with", "spf", "pa", "uv", "ml", "gr", "gram", "pcs", "new"}


def get(url, timeout=45, referer=None):
    headers = {"User-Agent": UA, "Accept": "text/html,application/json,*/*"}
    if referer:
        headers["Referer"] = referer
    return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=timeout).read()


def text(url):
    return get(url).decode("utf-8", "replace")


def words(value):
    t = re.split(r"[^a-z0-9]+", H.unescape(str(value)).lower())
    return [x for x in t if len(x) > 2 and x not in STOP]


def score(name, candidate):
    want = set(words(name))
    return len(want & set(words(candidate))) / len(want) if want else 0.0


def best(name, items):
    """Pilih kandidat dengan irisan kata terbanyak; kalau seri, yang paling sedikit kata tambahan."""
    want = set(words(name))
    ranked = []
    for label, payload in items:
        got = set(words(label))
        overlap = len(want & got) / len(want) if want else 0.0
        if overlap >= 0.6:
            ranked.append((overlap, len(got - want), payload))
    if not ranked:
        return None
    ranked.sort(key=lambda x: (-x[0], x[1]))
    if len(ranked) > 1 and ranked[0][:2] == ranked[1][:2]:
        return None
    return ranked[0][2]


def shopify_items(base):
    items, page = [], 1
    while page <= 4:
        for attempt in range(3):
            try:
                data = json.loads(text(f"{base}/products.json?limit=250&page={page}"))
                break
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(15 * (attempt + 1))
        products = data.get("products") or []
        if not products:
            break
        for p in products:
            imgs = [i.get("src") for i in (p.get("images") or []) if i.get("src")]
            if imgs:
                items.append((p.get("title") or "", imgs[0]))
        page += 1
    return items


def sitemap_pages(url, pattern):
    xml = text(url)
    urls = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", xml)
    if "<sitemapindex" in xml:
        urls = [u for child in urls
                for u in re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", text(child))]
    return [u for u in urls if re.search(pattern, u)]


def page_image(url, kind):
    page = text(url)
    if kind == "og":
        m = re.search(r'property="og:image"[^>]*content="([^"]+)"', page) or \
            re.search(r'content="([^"]+)"[^>]*property="og:image"', page)
        return H.unescape(m.group(1)) if m else None
    if kind == "flitts":
        m = re.search(r'https://flitts[^"\s]+', page)
        return m.group(0) if m else None
    if kind == "somethinc":
        cands = re.findall(r'https://images\.somethinc\.com/[^"\s]+', page)
        return best(url.rsplit("/", 1)[-1], [(c.rsplit("/", 1)[-1], c) for c in cands])
    return None


def download(url, brand, name):
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    data = get(url, timeout=60, referer=url)
    if data[:3] == b"\xff\xd8\xff":
        ext = ".jpg"
    elif data[:8] == b"\x89PNG\r\n\x1a\n":
        ext = ".png"
    elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        ext = ".webp"
    else:
        return None
    if len(data) < 5000:
        return None
    fname = re.sub(r"[^a-z0-9]+", "-", f"{brand}-{name}".lower()).strip("-")[:90] + ext
    (IMG_DIR / fname).write_bytes(data)
    return f"/uploads/products/{fname}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="data/products.csv")
    ap.add_argument("--brand", action="append")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = ROOT / args.csv
    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    cols = list(rows[0].keys())
    brands = args.brand or (list(SHOPIFY) + list(SITEMAP))

    pool = {}
    for brand in brands:
        try:
            if brand in SHOPIFY:
                pool[brand] = shopify_items(SHOPIFY[brand])
            elif brand in SITEMAP:
                smap, pat, kind = SITEMAP[brand]
                urls = sitemap_pages(smap, pat)
                pool[brand] = [(urllib.parse.unquote(u.rstrip("/").rsplit("/", 1)[-1]).replace("-", " "), u)
                               for u in urls]
            else:
                continue
            print(f"{brand}: {len(pool[brand])} kandidat")
        except Exception as exc:
            print(f"{brand}: GAGAL ambil kandidat ({exc})")

    done = 0
    for row in rows:
        brand = row["brand"]
        if brand not in pool or row.get("image_url"):
            continue
        hit = best(row["name"], pool[brand])
        if not hit:
            print(f"  - tidak cocok: {brand} - {row['name']}")
            continue
        if args.dry_run:
            print(f"  ~ {brand} - {row['name'][:42]} -> {hit[:100]}")
            done += 1
            continue
        try:
            img = page_image(hit, SITEMAP[brand][2]) if brand in SITEMAP else hit
            local = download(img, brand, row["name"]) if img else None
        except Exception as exc:
            print(f"  ! gagal {brand} - {row['name']}: {exc}")
            continue
        if local:
            row["image_url"] = local
            done += 1
            print(f"  + {brand} - {row['name'][:42]} -> {local}")
        else:
            print(f"  - gambar tidak ditemukan di halaman: {brand} - {row['name']}")
        time.sleep(0.3)

    if not args.dry_run:
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
            w.writeheader()
            w.writerows(rows)
    print(f"\nimage_url terisi: {done}/{len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
