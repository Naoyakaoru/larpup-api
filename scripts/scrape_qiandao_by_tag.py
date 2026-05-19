"""
scrape_qiandao_by_tag.py — Search-based scraper for qiandao scripts.

Instead of using the hot feed (limited to ~1000), this script searches
by genre tag ID to bypass the limit and collect a much larger dataset.

Usage:
    .venv/bin/python scripts/scrape_qiandao_by_tag.py

Output:
    scripts/qiandao_scripts_tagged_<timestamp>.csv
"""
import asyncio
import csv
import json
import re
import sys
import time
from pathlib import Path

import opencc
import requests
from auth_helper import capture_signed_headers

# Simplified → Traditional converter
_cc = opencc.OpenCC("s2t")

def s2t(text: str) -> str:
    return _cc.convert(text) if text else text


DIFFICULTY_MAP = {
    "入門": "easy", "新手": "easy", "輕度": "easy", "普通": "easy",
    "中度": "medium", "進階": "medium",
    "困難": "hard", "燒腦": "hard", "重度": "hard", "重恐": "hard",
}

def normalize_difficulty(raw: str) -> str:
    key = re.sub(r"[/(（].*", "", raw).strip()
    return DIFFICULTY_MAP.get(key, "medium")


# Genre name → internal ID mapping (Traditional Chinese)
GENRE_MAP = {
    "推理": 0, "恐怖": 1, "驚悚": 1, "微恐": 1,
    "情感": 3, "純愛": 3, "治癒": 3, "親情": 3,
    "歡樂": 4, "沉浸": 5, "演繹": 6, "演繹交互": 6,
    "古風": 7, "古代": 7, "武俠": 7, "仙俠": 7, "中式": 7,
    "現代": 8, "近現代": 8, "都市": 8, "校園": 8, "豪門": 8,
    "架空": 9, "玄幻": 9, "奇幻": 9, "科幻": 9, "未來": 9,
    "本格": 10, "新本格": 10, "邏輯": 10,
    "機制": 11, "設定系": 11,
    "還原": 12, "反轉": 13,
    "城限": 15, "獨家": 16,
    "硬核": 0, "燒腦": 0, "變格": 0, "詭計": 0, "懸疑": 0,
    "立意": 5, "日式": 0, "歐式": 0, "韓風": 0,
    "權謀": 9, "家國": 9, "歷史": 9, "民國": 8,
    "脫洞": 11, "話劇": 6, "撕逼": 3, "末世": 9,
}

def normalize_genres(raw: str) -> str:
    parts = re.split(r"[、,，\s]+", raw.strip())
    ids = [str(GENRE_MAP[p]) for p in parts if p in GENRE_MAP]
    seen = set()
    unique = []
    for i in ids:
        if i not in seen:
            seen.add(i)
            unique.append(i)
    return ",".join(unique)


# Genre tag IDs to search by (covers all major categories)
# Each tag search can return up to ~1000 unique scripts
SEARCH_TAG_IDS = {
    "推理": "1157841",
    "情感": "1157857",
    "恐怖": "1157861",
    "欢乐": "1157807",
    "沉浸": "1157795",
    "演绎": "1157779",
    "古风": "1208666",
    "现代": "1157753",
    "架空": "1157811",
    "本格": "1157817",
    "机制": "1157815",
    "还原": "1157649",
    "反转": "1157937",
    "城限": "1157911",
    "科幻": "1157729",
    "玄幻": "1157755",
    "武侠": "1157801",
    "民国": "1157799",
    "悬疑": "1157859",
    "烧脑": "1157775",
    "都市": "1157637",
}

FEED_URL = "https://api.qiandao.com/treasure/ssr/spu/feed"
BATCH = 60
TYPE_ID = "1000225"
PROPERTY_IDS = ["1152095", "1152081", "1152112", "1152085", "53156", "55407"]
PROP_PLAYER_COUNT = "1152081"
PROP_CROSS_GENDER  = "1152112"
PROP_DIFFICULTY    = "1152085"
PROP_DURATION      = "1152095"
PROP_DESCRIPTION   = "55407"

CATALOG_URL = (
    "https://qiandao.com/island/catalog"
    "?id=300231"
    "&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&title=%E6%89%BE%E5%89%A7%E6%9C%AC"
)

KEEP_HEADERS = [
    "x-request-timestamp", "x-request-sign", "x-request-sign-type",
    "x-request-sign-version", "x-request-package-sign-version",
    "x-request-package-id", "x-request-version", "x-client-package-id",
    "x-echoing-env", "accept", "content-type", "referer", "user-agent",
]


def fetch_page_with_tag(headers: dict, tag_id: str, offset: int) -> dict:
    payload = {
        "limit": BATCH,
        "offset": offset,
        "orderBy": "waterfallScoreDesc",
        "scene": "1column",
        "typeId": TYPE_ID,
        "withMarkStatus": True,
        "mustShouldTagIds": [{"tagIds": [tag_id]}],
        "propertyIds": PROPERTY_IDS,
    }
    resp = requests.post(FEED_URL, json=payload, headers=headers, timeout=20, verify=False)
    return resp.json()


def extract_profile(profiles, property_id):
    for group in profiles:
        if group.get("propertyId") == property_id:
            return [p["dataValue"] for p in group.get("profiles", []) if "dataValue" in p]
    return []


def parse_player_count(raw: str):
    raw = raw.strip()
    m = re.match(r"(\d+)男(\d+)女(?:(\d+)中性)?", raw)
    if m:
        male, female = int(m.group(1)), int(m.group(2))
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


def parse_item(item: dict) -> dict:
    profiles = item.get("profiles", [])
    kpc_raw = s2t(item.get("keyPropertyContent", ""))
    kpc_parts = re.split(r"\s*/\s*", kpc_raw)

    publisher_raw = s2t(item.get("mainTagDisplayName", ""))

    player_raw = extract_profile(profiles, PROP_PLAYER_COUNT)
    male, female, any_, total_slots = parse_player_count(player_raw[0] if player_raw else "")

    cross_raw = extract_profile(profiles, PROP_CROSS_GENDER)
    allow_cross = bool(cross_raw and "反串" in cross_raw[0])

    diff_raw = extract_profile(profiles, PROP_DIFFICULTY)
    difficulty_norm = normalize_difficulty(s2t(diff_raw[0])) if diff_raw else "medium"

    dur_raw = extract_profile(profiles, PROP_DURATION)
    duration_hours = parse_duration(s2t(dur_raw[0])) if dur_raw else None

    # Extract genres from keyPropertyContent: "剧本杀 / publisher / dist_type / genres"
    genres_text = ""
    if len(kpc_parts) >= 4:
        dist_type = kpc_parts[2].strip()
        tags = re.sub(r"\s+", "、", kpc_parts[3].strip())
        genres_text = f"{dist_type}、{tags}" if dist_type else tags
    elif len(kpc_parts) == 3:
        genres_text = re.sub(r"\s+", "、", kpc_parts[2].strip())

    desc_raw = extract_profile(profiles, PROP_DESCRIPTION)
    description = s2t(desc_raw[0]) if desc_raw else ""

    cover_url = item.get("cover", "")
    cover_image_id = ""
    if cover_url:
        m = re.search(r"\.image/([^?]+)", cover_url)
        if m:
            cover_image_id = m.group(1)

    return {
        "id": item["id"],
        "title": s2t(item.get("name", "")),
        "rating": item.get("rate", {}).get("rating"),
        "wish_count": item.get("wishCount", ""),
        "total_slots": total_slots,
        "male_slots": male,
        "female_slots": female,
        "any_slots": any_,
        "allow_cross_gender": allow_cross,
        "difficulty": diff_raw[0] if diff_raw else "",
        "difficulty_norm": difficulty_norm,
        "genres": genres_text,
        "genres_norm": normalize_genres(genres_text),
        "duration_hours": duration_hours,
        "publisher": publisher_raw,
        "cover_url": cover_url,
        "cover_image_id": cover_image_id,
        "key_property_content": kpc_raw,
        "description": description,
    }


def main():
    max_per_tag = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    headers = asyncio.run(capture_signed_headers())
    if not headers:
        print("ERROR: could not capture signed headers")
        return

    print(f"Using headers: {list(headers.keys())}")
    
    master_csv = Path(__file__).parent / "qiandao_scripts_tagged_master.csv"
    completed_tags_file = Path(__file__).parent / "completed_tags.json"
    
    completed_tags = []
    if completed_tags_file.exists():
        try:
            completed_tags = json.loads(completed_tags_file.read_text(encoding="utf-8"))
        except:
            pass

    fieldnames = [
        "id", "title", "rating", "wish_count",
        "total_slots", "male_slots", "female_slots", "any_slots",
        "allow_cross_gender", "difficulty", "difficulty_norm",
        "genres", "genres_norm", "duration_hours",
        "publisher", "cover_url", "cover_image_id", "key_property_content",
        "description",
    ]
    
    # Ensure CSV has headers if it doesn't exist
    if not master_csv.exists():
        with open(master_csv, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()

    for genre_name, tag_id in SEARCH_TAG_IDS.items():
        if tag_id in completed_tags:
            print(f"[SKIP] Tag '{genre_name}' already processed in previous runs.")
            continue

        print(f"\n[TAG] Searching '{genre_name}' (tag_id={tag_id})...")

        probe = fetch_page_with_tag(headers, tag_id, 0)
        if probe.get("code") != 0:
            print(f"  API error on probe: {probe}")
            print("\n[STOP] 遇到防爬蟲或驗證碼過期，請等待幾分鐘後再重新執行腳本 (它會自動從斷點繼續！)")
            sys.exit(1)
            
        tag_total = int(probe["data"].get("count") or 0)
        items = list(probe["data"].get("list") or [])
        cap = min(tag_total, max_per_tag)
        print(f"  Total for '{genre_name}': {tag_total}  |  will fetch up to {cap}")

        offset = BATCH
        error_hit = False
        while offset < cap and items:
            data = fetch_page_with_tag(headers, tag_id, offset)
            if data.get("code") != 0:
                print(f"  API error: {data}")
                error_hit = True
                break
            if not data.get("data"):
                break
                
            batch = data["data"].get("list") or []
            if not batch:
                break
            items.extend(batch)
            offset += BATCH
            time.sleep(0.5)

        # Parse new items
        new_rows = []
        for item in items:
            new_rows.append(parse_item(item))

        # Append to CSV
        with open(master_csv, "a", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writerows(new_rows)
            
        print(f"  Saved {len(new_rows)} items for '{genre_name}' to master CSV.")
        
        if error_hit:
            print("\n[STOP] 遇到防爬蟲或驗證碼過期，腳本暫停。請稍後再重新執行 (它會自動接續)！")
            sys.exit(1)

        # Mark tag as complete
        completed_tags.append(tag_id)
        completed_tags_file.write_text(json.dumps(completed_tags))
        time.sleep(2)


if __name__ == "__main__":
    main()
