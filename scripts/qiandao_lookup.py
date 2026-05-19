"""
qiandao_lookup.py — Search by title and return parsed script data as JSON.

Usage:
    python qiandao_lookup.py "劇本名稱（繁體）"

Output:
    JSON with script fields ready for import, printed to stdout.
"""
import asyncio
import json
import re
import sys

import opencc
import requests

from auth_helper import capture_signed_headers

SEARCH_URL = "https://api.qiandao.com/plast/search/chaos/v5"
FEED_URL   = "https://api.qiandao.com/treasure/ssr/spu/feed"
CDN_BASE   = "https://treasure.qiandaocdn.com/treasure/images"
CDN_SUFFIX = "!lfit_w600"

SEARCH_HEADERS = {
    "content-type": "application/json",
    "referer": "https://qiandao.com/",
    "user-agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
}

PROPERTY_IDS = ["1152095", "1152081", "1152112", "1152085", "53156", "55407"]
PROP_PLAYER  = "1152081"  # 人数
PROP_DIFF    = "1152085"  # 难度
PROP_DUR     = "1152095"  # 时长
PROP_DESC    = "55407"    # 描述

_cc_t2s = opencc.OpenCC("t2s")
_cc_s2t = opencc.OpenCC("s2t")

DIFFICULTY_MAP = {
    "入门": "easy", "新手": "easy", "轻度": "easy",
    "进阶": "medium", "普通": "medium",
    "困难": "hard", "烧脑": "hard", "重度": "hard",
}

# Correct mapping — matches Script::GENRES enum order exactly
GENRE_MAP = {
    # 0: 推理
    "推理": 0, "本格": 0, "新本格": 0, "逻辑": 0,
    # 1: 還原
    "还原": 1, "反转": 1,
    # 2: 恐怖
    "恐怖": 2, "惊悚": 2, "微恐": 2,
    # 3: 情感
    "情感": 3, "纯爱": 3, "治愈": 3, "亲情": 3,
    # 4: 歡樂
    "欢乐": 4,
    # 5: 機制
    "机制": 5, "设定系": 5,
    # 6: 陣營
    "阵营": 6,
    # 7: 古風
    "古风": 7, "古代": 7, "武侠": 7, "仙侠": 7,
    # 8: 現代
    "现代": 8, "近现代": 8, "都市": 8, "校园": 8, "豪门": 8,
    # 9: 日式
    "日式": 9,
    # 10: 中式
    "中式": 10,
    # 11: 民國
    "民国": 11,
    # 12: 社會
    "社会": 12,
    # 13: 刑偵
    "刑侦": 13,
    # 14: 演繹
    "演绎": 14, "演绎交互": 14, "沉浸": 14,
    # 15: 城限
    "城限": 15,
    # 16: 獨家
    "独家": 16,
}


def extract_cover_id(url: str) -> str:
    if not url:
        return ""
    m = re.search(r"\.image/([^?]+)", url)
    return m.group(1) if m else ""


def cover_cdn_url(cover_id: str) -> str:
    return f"{CDN_BASE}/{cover_id}{CDN_SUFFIX}" if cover_id else ""


def parse_slots(values: list[str]):
    """Parse player count from strings like '4男3女', '6人', or tag_names with '/(...)' suffix."""
    for val in values:
        name = re.sub(r"[/(（].*", "", val).strip()
        m = re.match(r"(\d+)男(\d+)女", name)
        if m:
            return int(m.group(1)), int(m.group(2)), 0
        m = re.match(r"(\d+)人", name)
        if m:
            return 0, 0, int(m.group(1))
    return 0, 0, 0


def parse_difficulty(values: list[str]) -> str:
    for val in values:
        raw = re.sub(r"[/(（].*", "", val).strip()
        if raw in DIFFICULTY_MAP:
            return DIFFICULTY_MAP[raw]
    return "medium"


def parse_genres(values: list[str]) -> list[int]:
    seen: set[int] = set()
    result = []
    for val in values:
        raw = re.sub(r"[/(（].*", "", val).strip()
        gid = GENRE_MAP.get(raw)
        if gid is not None and gid not in seen:
            seen.add(gid)
            result.append(gid)
    return result


def extract_profile(profiles: list, property_id: str) -> list[str]:
    for group in profiles:
        if group.get("propertyId") == property_id:
            return [p["dataValue"] for p in group.get("profiles", []) if "dataValue" in p]
    return []


async def search_qiandao(title_zh_tw: str) -> dict | None:
    title_s = _cc_t2s.convert(title_zh_tw)

    # Step 1: text search (no auth needed)
    resp = requests.post(
        SEARCH_URL,
        json={"q": title_s, "startIndex": 0, "maxResults": 10,
              "origin": "search", "version": "5", "scene": "qiandao_web"},
        headers=SEARCH_HEADERS, timeout=15, verify=False,
    )
    items = resp.json().get("data", {}).get("items") or []

    spu = None
    for item in items:
        if item.get("type") != "spu":
            continue
        show = item.get("spuShow", {})
        if not show.get("type_id"):
            continue
        if show.get("name", "") == title_s:
            spu = show
            break
        if spu is None:
            spu = show

    if not spu:
        return None

    spu_id   = spu.get("id", "")
    cover_id = extract_cover_id(spu.get("image", "") or "")
    kp       = spu.get("key_property", "")
    kp_parts = [p.strip() for p in kp.split("/")]
    publisher = _cc_s2t.convert(kp_parts[1] if len(kp_parts) >= 2 else "")

    # Step 2: fetch detailed profiles via feed API (requires signed headers)
    signed = await capture_signed_headers()
    detail = None
    if signed:
        try:
            payload = {
                "limit": 1, "offset": 0,
                "orderBy": "waterfallScoreDesc",
                "scene": "1column", "typeId": "1000225",
                "spuId": spu_id,
                "propertyIds": PROPERTY_IDS,
            }
            r = requests.post(FEED_URL, json=payload, headers=signed, timeout=15, verify=False)
            items2 = (r.json().get("data") or {}).get("list") or []
            detail = items2[0] if items2 else None
        except Exception:
            pass

    if detail:
        profiles    = detail.get("profiles", [])
        player_raw  = extract_profile(profiles, PROP_PLAYER)
        diff_raw    = extract_profile(profiles, PROP_DIFF)
        dur_raw     = extract_profile(profiles, PROP_DUR)
        desc_raw    = extract_profile(profiles, PROP_DESC)

        male, female, any_ = parse_slots(player_raw)
        difficulty = DIFFICULTY_MAP.get(diff_raw[0].strip(), "medium") if diff_raw else "medium"
        dur_m      = re.match(r"(\d+)", (dur_raw[0] or "").strip()) if dur_raw else None
        duration   = int(dur_m.group(1)) if dur_m else None
        description = _cc_s2t.convert(desc_raw[0]) if desc_raw else ""
        genres = parse_genres(detail.get("tag_names") or []) or parse_genres(spu.get("tag_names") or [])
    else:
        # Fallback: search tag_names only (no male/female breakdown, no duration)
        tag_names   = spu.get("tag_names") or []
        male, female, any_ = parse_slots(tag_names)
        difficulty  = parse_difficulty(tag_names)
        genres      = parse_genres(tag_names)
        duration    = None
        description = ""

    return {
        "qiandao_id":     spu_id,
        "title":          _cc_s2t.convert(spu.get("name", title_zh_tw)),
        "difficulty":     difficulty,
        "genres":         genres,
        "male_slots":     male,
        "female_slots":   female,
        "any_slots":      any_,
        "duration":       duration,
        "description":    description,
        "publisher":      publisher,
        "cover_image_id": cover_id,
        "cover_cdn_url":  cover_cdn_url(cover_id),
        "key_property":   _cc_s2t.convert(kp),
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: qiandao_lookup.py <title>"}))
        sys.exit(1)

    result = asyncio.run(search_qiandao(sys.argv[1]))
    if result:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(json.dumps({"error": f"Not found: {sys.argv[1]}"}))
