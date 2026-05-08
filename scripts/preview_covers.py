"""Bulk download cover images from qiandao_scripts.csv."""
import csv
import sys
import time
import requests
import urllib3
from pathlib import Path

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

CSV = Path(__file__).parent / "qiandao_scripts.csv"
OUT = Path(__file__).parent / "covers"
OUT.mkdir(exist_ok=True)

def to_http(url: str) -> str:
    if url.startswith("echotechoss://"):
        _, _, rest = url.split("echotechoss://", 1)[1].partition("/")
        return f"https://treasure.qiandaocdn.com/treasure/images/{rest.split('?')[0]}"
    return url

with open(CSV, newline="", encoding="utf-8") as f:
    rows = [r for r in csv.DictReader(f) if r.get("cover_url")]

total = len(rows)
ok = skip = 0

for i, row in enumerate(rows):
    url = to_http(row["cover_url"])
    ext = url.rsplit(".", 1)[-1].split("?")[0] or "jpg"
    if len(ext) > 4:
        ext = "jpg"
    dest = OUT / f"{row['id']}.{ext}"

    if dest.exists():
        skip += 1
        continue

    try:
        r = requests.get(url, timeout=15, verify=False, headers={"User-Agent": "Mozilla/5.0"})
        r.raise_for_status()
        dest.write_bytes(r.content)
        ok += 1
        print(f"[{i+1}/{total}] {dest.name}")
    except Exception as e:
        print(f"[{i+1}/{total}] SKIP {row['id']} — {e}", file=sys.stderr)

    time.sleep(0.1)

print(f"\nDone: {ok} downloaded, {skip} already existed → {OUT}/")
