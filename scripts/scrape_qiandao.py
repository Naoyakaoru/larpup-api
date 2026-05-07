"""
Scrape 千島 (qiandao.com) 劇本殺 catalog.
Strategy:
  1. Load catalog page in Playwright to capture a real signed request
  2. Extract auth headers (x-request-sign, x-request-timestamp, etc.)
  3. Use those headers in Python requests for paginated fetches
  4. Convert Simplified Chinese → Traditional Chinese via opencc

Output: qiandao_scripts.csv
Columns include `difficulty_norm` (easy/medium/hard) and `genres_norm`
(comma-separated integers matching the platform's genre enum).
"""
import asyncio
import csv
import json
import re
import time
from pathlib import Path

import opencc
import requests
from playwright.async_api import async_playwright

# Simplified → Traditional converter
_cc = opencc.OpenCC("s2t")

def s2t(text: str) -> str:
    return _cc.convert(text) if text else text


# Difficulty mapping (Traditional Chinese after conversion)
DIFFICULTY_MAP = {
    "入門": "easy", "新手": "easy", "輕度": "easy", "普通": "easy",
    "中度": "medium", "進階": "medium",
    "困難": "hard", "燒腦": "hard", "重度": "hard", "重恐": "hard",
}

def normalize_difficulty(raw: str) -> str:
    # strip parenthetical suffixes like "進階/(劇本殺難度)"
    key = re.sub(r"[/(（].*", "", raw).strip()
    return DIFFICULTY_MAP.get(key, "medium")  # default medium if unknown


# Genre mapping: Traditional Chinese label → platform integer
GENRE_MAP = {
    "推理": 0, "還原": 1, "恐怖": 2, "情感": 3,
    "歡樂": 4, "機制": 5, "陣營": 6, "古風": 7, "現代": 8,
    "日式": 9, "中式": 10, "民國": 11, "社會": 12, "刑偵": 13, "演繹": 14,
    "城限": 15, "獨家": 16,
}

def normalize_genres(raw: str) -> str:
    """Return comma-separated integers for known genres."""
    parts = re.split(r"[、,，\s]+", raw.strip())
    ids = [str(GENRE_MAP[p]) for p in parts if p in GENRE_MAP]
    return ",".join(ids)

CATALOG_URL = (
    "https://qiandao.com/island/catalog"
    "?id=300231"
    "&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&title=%E6%89%BE%E5%89%A7%E6%9C%AC"
)

FEED_URL = "https://api.qiandao.com/treasure/ssr/spu/feed"
BATCH = 60
TYPE_ID = "1000225"
PROPERTY_IDS = ["1152095", "1152081", "1152112", "1152085", "53156", "55407"]

# Property IDs for extraction
PROP_PLAYER_COUNT = "1152081"
PROP_CROSS_GENDER  = "1152112"
PROP_DIFFICULTY    = "1152085"
PROP_DURATION      = "1152095"
PROP_DESCRIPTION   = "55407"   # "简介" — intro/description paragraph text

KEEP_HEADERS = [
    "x-request-timestamp",
    "x-request-sign",
    "x-request-sign-type",
    "x-request-sign-version",
    "x-request-package-sign-version",
    "x-request-package-id",
    "x-request-version",
    "x-client-package-id",
    "x-echoing-env",
    "accept",
    "content-type",
    "referer",
    "user-agent",
]


async def capture_signed_headers() -> dict:
    """Load the catalog page and capture the HMAC-signed headers from the feed request."""
    captured = {}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        )
        page = await context.new_page()

        async def on_request(request):
            if "ssr/spu/feed" in request.url and not captured:
                for k, v in request.headers.items():
                    if k.lower() in KEEP_HEADERS:
                        captured[k.lower()] = v
                print(f"Captured {len(captured)} signed headers")

        page.on("request", on_request)

        print("Loading catalog page to capture signed headers...")
        # Start navigation without waiting for full load
        asyncio.ensure_future(
            page.goto(CATALOG_URL, wait_until="commit", timeout=60000)
        )
        # Wait up to 30s for the feed request to appear
        for _ in range(30):
            if captured:
                break
            await asyncio.sleep(1)
        if not captured:
            # try scrolling
            try:
                await page.evaluate("window.scrollBy(0, 300)")
            except Exception:
                pass
            await asyncio.sleep(5)

        await browser.close()

    return captured


def extract_profile(profiles, property_id):
    for group in profiles:
        if group.get("propertyId") == property_id:
            return [p["dataValue"] for p in group.get("profiles", [])]
    return []


def parse_player_count(raw: str):
    raw = raw.strip()
    m = re.match(r"(\d+)男(\d+)女(?:(\d+)中性)?", raw)
    if m:
        male = int(m.group(1))
        female = int(m.group(2))
        any_ = int(m.group(3)) if m.group(3) else 0
        return male, female, any_, male + female + any_
    m = re.match(r"(\d+)人", raw)
    if m:
        total = int(m.group(1))
        return 0, 0, total, total
    return 0, 0, 0, 0


def parse_duration(raw: str):
    m = re.match(r"(\d+)小时", raw.strip())
    return int(m.group(1)) if m else None


def fetch_page(headers: dict, offset: int) -> dict:
    payload = {
        "limit": BATCH,
        "offset": offset,
        "orderBy": "new",
        "scene": "1column",
        "typeId": TYPE_ID,
        "withMarkStatus": True,
        "propertyIds": PROPERTY_IDS,
    }
    resp = requests.post(FEED_URL, json=payload, headers=headers, timeout=20, verify=False)
    return resp.json()


def main():
    headers = asyncio.run(capture_signed_headers())
    if not headers:
        print("ERROR: could not capture signed headers")
        return

    print(f"Using headers: {list(headers.keys())}")

    # first request to get total count
    first = fetch_page(headers, 0)
    if first.get("code") != 0:
        print(f"API error on first request: {first}")
        return

    total = int(first["data"]["count"])
    all_items = list(first["data"]["list"])
    print(f"Total: {total}  |  fetched: {len(all_items)}")

    offset = BATCH
    cap = min(total, 500)  # newest 500
    while offset < cap:
        data = fetch_page(headers, offset)
        if data.get("code") != 0 or not data.get("data"):
            print(f"Stopping at offset {offset}: code={data.get('code')} data={str(data)[:200]}")
            break
        batch = data["data"].get("list") or []
        if not batch:
            break
        all_items.extend(batch)
        print(f"  fetched {len(all_items)} / {cap}")
        offset += BATCH
        time.sleep(0.3)

    print(f"\nParsing {len(all_items)} items...")
    out_path = Path(__file__).parent / "qiandao_scripts.csv"
    fieldnames = [
        "id", "title", "rating", "wish_count",
        "total_slots", "male_slots", "female_slots", "any_slots",
        "allow_cross_gender",
        "difficulty", "difficulty_norm",
        "genres", "genres_norm",
        "duration_hours",
        "publisher", "cover_url", "key_property_content",
        "description",
    ]

    rows = []
    for item in all_items:
        profiles = item.get("profiles", [])

        player_raw = extract_profile(profiles, PROP_PLAYER_COUNT)
        male, female, any_, total_slots = parse_player_count(player_raw[0]) if player_raw else (0,0,0,0)

        cross_raw = extract_profile(profiles, PROP_CROSS_GENDER)
        allow_cross = "可反串" in (cross_raw[0] if cross_raw else "")

        diff_raw = extract_profile(profiles, PROP_DIFFICULTY)
        difficulty_raw = s2t(diff_raw[0]) if diff_raw else ""

        dur_raw = extract_profile(profiles, PROP_DURATION)
        duration = parse_duration(dur_raw[0]) if dur_raw else None

        title = s2t(item["name"])
        key_content = s2t(item.get("keyPropertyContent", ""))

        # key_property_content: "劇本殺 / {publisher(s)} / {dist_type} / {tag1} {tag2}..."
        kpc_parts = [p.strip() for p in key_content.split("/")]
        publisher_kpc = kpc_parts[1].strip() if len(kpc_parts) > 1 else ""
        raw_pub = s2t(item.get("mainTagDisplayName", "")) or publisher_kpc
        # multiple publishers separated by spaces in Chinese text → use 、
        publisher = "、".join(raw_pub.split()) if raw_pub else ""

        # Genres come from kpc; profile 53156 has deprecated non-standard tags
        # kpc: "劇本殺 / {pub} / {城限|獨家|盒裝} / {tag1} {tag2}..."
        # or 3-part when dist_type absent: "劇本殺 / {pub} / {tag1} {tag2}..."
        if len(kpc_parts) >= 4:
            genres_text = re.sub(r"\s+", "、", kpc_parts[3].strip())
        elif len(kpc_parts) == 3:
            genres_text = re.sub(r"\s+", "、", kpc_parts[2].strip())
        else:
            genres_text = ""

        # Description is in property 55407 ("简介") as a paragraph
        desc_raw = extract_profile(profiles, PROP_DESCRIPTION)
        description = s2t(desc_raw[0]) if desc_raw else ""

        rows.append({
            "id": item["id"],
            "title": title,
            "rating": item.get("rate", {}).get("rating"),
            "wish_count": item.get("wishCount", ""),
            "total_slots": total_slots,
            "male_slots": male,
            "female_slots": female,
            "any_slots": any_,
            "allow_cross_gender": allow_cross,
            "difficulty": difficulty_raw,
            "difficulty_norm": normalize_difficulty(difficulty_raw),
            "genres": genres_text,
            "genres_norm": normalize_genres(genres_text),
            "duration_hours": duration,
            "publisher": publisher,
            "cover_url": item.get("cover", ""),
            "key_property_content": key_content,
            "description": description,
        })

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved {len(rows)} rows → {out_path}")


main()
