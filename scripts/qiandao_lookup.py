"""
qiandao_lookup.py — Search qiandao by title and return parsed script data as JSON.

Usage:
    python qiandao_lookup.py "劇本名稱（繁體）"

Output:
    JSON with script fields ready for import, printed to stdout.
"""
import json
import re
import sys
import opencc
import requests

SEARCH_URL = "https://api.qiandao.com/plast/search/chaos/v5"
CDN_BASE = "https://treasure.qiandaocdn.com/treasure/images"
CDN_SUFFIX = "!lfit_w600"

HEADERS = {
    "content-type": "application/json",
    "referer": "https://qiandao.com/",
    "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
}

_cc_t2s = opencc.OpenCC("t2s")
_cc_s2t = opencc.OpenCC("s2t")

DIFFICULTY_MAP = {
    "入门": "easy", "新手": "easy", "轻度": "easy",
    "进阶": "medium", "普通": "medium",
    "困难": "hard", "烧脑": "hard", "重度": "hard",
}

GENRE_MAP = {
    "推理": 0, "恐怖": 1, "惊悚": 1, "微恐": 1,
    "情感": 3, "纯爱": 3, "治愈": 3, "亲情": 3,
    "欢乐": 4, "沉浸": 5, "演绎": 6, "演绎交互": 6,
    "古风": 7, "古代": 7, "武侠": 7, "仙侠": 7, "中式": 7,
    "现代": 8, "近现代": 8, "都市": 8, "校园": 8, "豪门": 8, "民国": 8,
    "架空": 9, "玄幻": 9, "奇幻": 9, "科幻": 9, "未来": 9,
    "本格": 10, "新本格": 10, "逻辑": 10,
    "机制": 11, "设定系": 11,
    "还原": 12, "反转": 13,
    "城限": 15, "独家": 16,
}


def extract_cover_id(url: str) -> str:
    if not url:
        return ""
    m = re.search(r"\.image/([^?]+)", url)
    return m.group(1) if m else ""


def cover_cdn_url(cover_id: str) -> str:
    if not cover_id:
        return ""
    return f"{CDN_BASE}/{cover_id}{CDN_SUFFIX}"


def parse_slots(tag_names: list[str]):
    """Extract player count from tag_names like '6人/(剧本杀人数)' or '4男3女/(剧本杀人数)'."""
    for tag in tag_names:
        name = re.sub(r"\(.*", "", tag).strip()
        m = re.match(r"(\d+)男(\d+)女", name)
        if m:
            return int(m.group(1)), int(m.group(2)), 0
        m = re.match(r"(\d+)人", name)
        if m:
            return 0, 0, int(m.group(1))
    return 0, 0, 0


def parse_difficulty(tag_names: list[str]) -> str:
    for tag in tag_names:
        raw = re.sub(r"/.*", "", tag).strip()
        if raw in DIFFICULTY_MAP:
            return DIFFICULTY_MAP[raw]
    return "medium"


def parse_genres(tag_names: list[str]) -> list[int]:
    seen = set()
    result = []
    for tag in tag_names:
        raw = re.sub(r"/.*", "", tag).strip()
        gid = GENRE_MAP.get(raw)
        if gid is not None and gid not in seen:
            seen.add(gid)
            result.append(gid)
    return result


def search_qiandao(title_zh_tw: str) -> dict | None:
    """Search qiandao by Traditional Chinese title, return parsed script data."""
    title_simplified = _cc_t2s.convert(title_zh_tw)

    payload = {
        "q": title_simplified,
        "startIndex": 0,
        "maxResults": 10,
        "origin": "search",
        "version": "5",
        "scene": "qiandao_web",
    }
    resp = requests.post(SEARCH_URL, json=payload, headers=HEADERS, timeout=15, verify=False)
    data = resp.json()
    items = data.get("data", {}).get("items") or []

    # Find the best match (exact name match preferred, else first spu)
    spu = None
    for item in items:
        if item.get("type") != "spu":
            continue
        show = item.get("spuShow", {})
        if not show.get("type_id"):
            continue
        name_s = show.get("name", "")
        if name_s == title_simplified:
            spu = show
            break
        if spu is None:
            spu = show

    if not spu:
        return None

    tag_names = [re.sub(r"/.*", "", t).strip() for t in (spu.get("tag_names") or [])]
    cover_raw = spu.get("image", "") or ""
    cover_id = extract_cover_id(cover_raw)

    male, female, any_ = parse_slots(spu.get("tag_names") or [])
    difficulty = parse_difficulty(spu.get("tag_names") or [])
    genres = parse_genres(spu.get("tag_names") or [])

    # Parse publisher from key_property: "剧本杀 / Publisher / dist / genres"
    kp = spu.get("key_property", "")
    kp_parts = [p.strip() for p in kp.split("/")]
    publisher_simplified = kp_parts[1] if len(kp_parts) >= 2 else ""
    publisher = _cc_s2t.convert(publisher_simplified)

    return {
        "qiandao_id": spu.get("id", ""),
        "title": _cc_s2t.convert(spu.get("name", title_zh_tw)),
        "difficulty": difficulty,
        "genres": genres,
        "male_slots": male,
        "female_slots": female,
        "any_slots": any_,
        "publisher": publisher,
        "cover_image_id": cover_id,
        "cover_cdn_url": cover_cdn_url(cover_id),
        "key_property": _cc_s2t.convert(kp),
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: qiandao_lookup.py <title>"}))
        sys.exit(1)

    title = sys.argv[1]
    result = search_qiandao(title)
    if result:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(json.dumps({"error": f"Not found: {title}"}))
