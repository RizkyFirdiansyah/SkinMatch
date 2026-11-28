"""Ambil data katalog dari cekbpom.pom.go.id + INCI dari inkeedecoder.com.

Dua mode:
  1. Jelajah brand:  python scripts/catalog_lookup.py --brand Wardah --limit 20
  2. Isi kandidat:   python scripts/catalog_lookup.py --candidates data/candidates.csv --out data/catalog.csv

Format candidates.csv: kolom `brand,name` (satu produk per baris, nama boleh nama dagang).

Output kolom: brand,name,bpom_number,bpom_name,status,expired,registrant,package,
ingredients_text,source_url,inci_match

Catatan: BPOM tidak mempublikasikan komposisi kosmetik (field INGREDIENTS selalu kosong),
jadi INCI diambil dari INCIDecoder dan wajib dicek manual sebelum dipakai.
"""
import argparse
import csv
import http.cookiejar
import json
import re
import sys
import time
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
BPOM = "https://cekbpom.pom.go.id"
INCI = "https://inkeedecoder.com"
OUT_FIELDS = ["brand", "name", "bpom_number", "bpom_name", "bpom_match", "status", "expired",
              "registrant", "package", "ingredients_text", "source_url", "inci_match"]


def retry(fn, tries=4) -> bytes:
    """cekbpom sering putus di tengah jalan; ulangi dengan jeda makin panjang."""
    for i in range(tries):
        try:
            return fn()
        except OSError as e:
            if i == tries - 1:
                raise
            time.sleep(3 * (i + 1))


def http_get(opener, url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    return retry(lambda: opener.open(req, timeout=60).read()).decode("utf-8", "replace")


class Bpom:
    """Sesi cekbpom: cookie + CSRF sekali, lalu POST ke endpoint DataTables."""

    COLS = ["PRODUCT_ID", "PRODUCT_REGISTER", "PRODUCT_NAME", "MANUFACTURER_NAME"]

    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar))
        html = http_get(self.opener, f"{BPOM}/produk-kosmetika")
        found = re.search(r'name="csrf-token" content="([^"]+)"', html)
        if not found:
            sys.exit("cekbpom: meta csrf-token tidak ditemukan (layout situs berubah?)")
        self.token = found.group(1)

    def search(self, brand="", name="", limit=10, start=0):
        parts = ["draw=1", f"start={start}", f"length={limit}"]
        for i, col in enumerate(self.COLS):
            parts += [f"columns[{i}][data]={col}", f"columns[{i}][searchable]=false",
                      f"columns[{i}][orderable]=false", f"columns[{i}][search][value]=",
                      f"columns[{i}][search][regex]=false"]
        parts += ["order[0][column]=0", "order[0][dir]=desc", "search[value]=", "search[regex]=false",
                  "product_register=", f"product_name={urllib.parse.quote(name)}",
                  f"product_brand={urllib.parse.quote(brand)}", "product_package=", "product_form=",
                  "ingredients=", "submit_date_start=", "submit_date_end=", "product_date_start=",
                  "product_date_end=", "expire_date_start=", "expire_date_end=", "manufacturer_name=",
                  "status=", "release_date="]
        req = urllib.request.Request(
            f"{BPOM}/produk-dt/12", data="&".join(parts).encode(),
            headers={"X-CSRF-TOKEN": self.token, "Content-Type": "application/x-www-form-urlencoded",
                     "X-Requested-With": "XMLHttpRequest", "Referer": f"{BPOM}/produk-kosmetika"})
        with self.opener.open(req, timeout=90) as r:
            return json.loads(retry(r.read).decode())


def bpom_row(raw):
    return {
        "bpom_number": raw.get("PRODUCT_REGISTER") or "",
        "bpom_name": raw.get("PRODUCT_NAME") or "",
        "status": raw.get("STATUS") or "",
        "expired": raw.get("PRODUCT_EXPIRED") or "",
        "registrant": raw.get("REGISTRAR") or raw.get("MANUFACTURER_NAME") or "",
        "package": raw.get("PRODUCT_PACKAGE") or "",
        "source_url": f"{BPOM}/produk/{raw.get('PRODUCT_ID')}/{raw.get('APPLICATION_ID')}/detail",
    }


def tokens(text):
    return {t for t in re.split(r"[^a-z0-9]+", text.lower()) if len(t) > 2}


def words(text):
    """Token nama produk tanpa penanda SPF/PA yang bikin perbandingan nama kacau."""
    return {t for t in tokens(text) if not re.fullmatch(r"(spf|pa|uv)\d*", t)}


def pick_bpom(rows, name):
    """Pilih baris paling cocok: angka cocok, kata mirip, dan tidak ada kata asing mencurigakan."""
    if not rows:
        return None
    want = words(name)
    cand_num = re.findall(r"\d+(?:[.,]\d+)?%?", name.lower())

    def score(r):
        rn = r.get("PRODUCT_NAME") or ""
        row_tok = words(rn)
        row_num = re.findall(r"\d+(?:[.,]\d+)?%?", rn.lower())
        numbers_ok = all(n in row_num for n in cand_num)
        overlap = len(want & row_tok) / max(len(want), 1)
        extra = len(row_tok - want - {"madagascar", "centella"})
        return (numbers_ok, extra <= 1, overlap, r.get("STATUS") == "Berlaku")

    best = max(rows, key=score)
    numbers_ok, not_extra, overlap, _ = score(best)
    return best if numbers_ok and not_extra and overlap >= 0.7 else None


def bpom_search_best(bpom, brand, name):
    """Cari nama lengkap dulu; kalau kosong, potong kata dari belakang sampai dapat kandidat."""
    words = name.split()
    for n in range(len(words), 1, -1):
        query = " ".join(words[:n])
        data = bpom.search(brand=brand, name=query, limit=20)
        raw = pick_bpom(data.get("data", []), name)
        if raw:
            return raw
    return None


def bpom_match_quality(cand_name, bpom_name):
    """exact/partial/variant?. Angka beda (SPF 35 vs 30, 5% vs 10%) = varian lain, jangan tempel NIE."""
    if not bpom_name:
        return "none"
    num = lambda s: re.findall(r"\d+(?:[.,]\d+)?%?", s.lower())
    if any(n not in num(bpom_name) for n in num(cand_name)):
        return "variant?"
    overlap = len(tokens(cand_name) & tokens(bpom_name)) / max(len(tokens(cand_name)), 1)
    return "exact" if overlap >= 0.8 else "partial"


def inci_lookup(opener, brand, name):
    """Cari produk di INCIDecoder, ambil daftar bahan urut label. Return (text, url, match)."""
    q = urllib.parse.quote(f"{brand} {name}")
    try:
        html = http_get(opener, f"{INCI}/search?query={q}")
    except Exception as exc:
        return "", "", f"search-error: {exc}"
    pairs = re.findall(r'href="(/products/[^"]+)"[^>]*>\s*([^<]{0,120})', html)
    want = tokens(name)
    best = None
    for url, title in pairs:
        title = title.strip()
        if not title:
            continue
        overlap = len(want & tokens(title)) / max(len(want), 1)
        if overlap >= 0.6 and (best is None or overlap > best[0]):
            best = (overlap, url, title)
    if not best:
        return "", "", "manual"
    url = INCI + best[1]
    try:
        page = http_get(opener, url)
    except Exception as exc:
        return "", url, f"page-error: {exc}"
    start = page.find('id="ingredlist-short"')
    end = page.find('id="showmore-section-ingreddetail"', start)
    block = page[start:end if end > start else start + 40000]
    names = [re.sub(r"\s+", " ", n.replace("\u200b", "")).strip()
             for n in re.findall(r'class="ingred-link[^"]*"\s*>([^<]+)</a>', block)]
    names = [n for n in names if n and not n.lower().startswith("show")]
    names = list(dict.fromkeys(names))  # blok detail ikut ketangkep; urutan label = kemunculan pertama
    if not names:
        return "", url, "no-ingredients"
    return ", ".join(names), url, "auto"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--brand", action="append", default=[], help="jelajah produk terbaru brand ini")
    ap.add_argument("--limit", type=int, default=20, help="jumlah baris per brand (mode jelajah)")
    ap.add_argument("--candidates", help="CSV dengan kolom brand,name")
    ap.add_argument("--out", default="", help="file CSV output")
    ap.add_argument("--no-inci", action="store_true", help="lewati INCIDecoder")
    args = ap.parse_args()

    if not args.brand and not args.candidates:
        sys.exit("pakai --brand NAMA atau --candidates file.csv")

    bpom = Bpom()
    opener = urllib.request.build_opener()
    opener.addheaders = [("User-Agent", UA)]
    out = []

    if args.brand:
        for brand in args.brand:
            data = bpom.search(brand=brand, limit=args.limit)
            print(f"{brand}: {data.get('recordsFiltered', 0)} produk terdaftar, ambil {len(data.get('data', []))}")
            for raw in data.get("data", []):
                row = {"brand": raw.get("PRODUCT_BRANDS") or brand, "name": raw.get("PRODUCT_NAME") or ""}
                row.update(bpom_row(raw))
                out.append(row)
            time.sleep(1)

    for cand in ([] if not args.candidates else read_candidates(args.candidates)):
        try:
            raw = bpom_search_best(bpom, cand["brand"], cand["name"])
        except OSError as e:
            print(f"  GAGAL koneksi, lewati: {cand['brand']} - {cand['name']} ({e})")
            out.append({"brand": cand["brand"], "name": cand["name"], "bpom_number": "", "bpom_name": "",
                        "bpom_match": "error", "status": "", "expired": "", "registrant": "", "package": "",
                        "ingredients_text": "", "source_url": "", "inci_match": "error", "inci_url": ""})
            continue
        row = {"brand": cand["brand"], "name": cand["name"]}
        if raw:
            row.update(bpom_row(raw))
            row["bpom_match"] = bpom_match_quality(cand["name"], raw.get("PRODUCT_NAME") or "")
            if row["bpom_match"] == "variant?":
                row["bpom_number"] = ""  # NIE varian lain lebih berbahaya daripada kosong
        else:
            row.update({"bpom_number": "", "bpom_name": "", "bpom_match": "none", "status": "",
                        "expired": "", "registrant": "", "package": "", "source_url": ""})
            print(f"  BPOM tidak ketemu: {cand['brand']} - {cand['name']}")
        if args.no_inci:
            row.update({"ingredients_text": "", "inci_match": "skipped", "source_url": row.get("source_url", "")})
        else:
            text, url, match = inci_lookup(opener, cand["brand"], cand["name"])
            row["ingredients_text"] = text
            row["inci_match"] = match
            row["inci_url"] = url
        out.append(row)
        print(f"  {row.get('bpom_number') or '-'} | {cand['name']} | inci: {row.get('inci_match')}")
        time.sleep(1)

    if not out:
        sys.exit("tidak ada data")

    fields = OUT_FIELDS + (["inci_url"] if any("inci_url" in r for r in out) else [])
    if args.out:
        with open(args.out, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(out)
        print(f"\n{len(out)} baris -> {args.out}")
    else:
        writer = csv.DictWriter(sys.stdout, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(out)


def read_candidates(path):
    with open(path, newline="", encoding="utf-8") as f:
        rows = [{"brand": r["brand"].strip(), "name": r["name"].strip()}
                for r in csv.DictReader(f) if r.get("brand") and r.get("name")]
    return rows


if __name__ == "__main__":
    main()
