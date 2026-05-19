"""
Extract all genre tag IDs from the qiandao catalog filter sidebar.
Saves a JSON mapping of genre_name -> tag_id.
"""
import json
import asyncio
from playwright.async_api import async_playwright

CATALOG_URL = (
    "https://qiandao.com/island/catalog"
    "?id=300231"
    "&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&title=%E6%89%BE%E5%89%A7%E6%9C%AC"
)

# Also capture tag IDs from feed responses
tag_ids_from_feed: dict[str, str] = {}

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        async def on_response(response):
            if "ssr/spu/feed" in response.url:
                try:
                    body = await response.json()
                    items = (body.get("data") or {}).get("list") or []
                    for item in items:
                        for profile_group in item.get("profiles", []):
                            for p in profile_group.get("profiles", []):
                                tid = p.get("targetId")
                                tname = p.get("dataValue")
                                if tid and tname and p.get("targetType") == "tag":
                                    tag_ids_from_feed[tname] = tid
                except Exception:
                    pass

        page.on("response", on_response)

        print("Loading catalog page...")
        await page.goto(CATALOG_URL, wait_until="domcontentloaded", timeout=60000)
        await asyncio.sleep(4)

        # Scroll to trigger more data
        for _ in range(5):
            try:
                await page.evaluate("window.scrollBy(0, 500)")
            except Exception:
                pass
            await asyncio.sleep(1)

        await asyncio.sleep(2)

        # Try to extract filter tag IDs from the sidebar DOM
        tag_map = {}
        try:
            # qiandao renders filter chips with data attributes or text
            elements = await page.query_selector_all("[class*='filter'] [class*='tag'], [class*='Filter'] [class*='Tag'], [class*='label']")
            print(f"Found {len(elements)} potential filter elements")
            for el in elements:
                text = await el.inner_text()
                text = text.strip()
                if text:
                    # Try to get any data attribute
                    attrs = await el.evaluate("el => ({...el.dataset})")
                    print(f"  Text: {text!r}  attrs: {attrs}")
        except Exception as e:
            print(f"DOM extraction error: {e}")

        # Print all tag IDs captured from feed responses
        print(f"\n{'='*60}")
        print(f"Tag IDs captured from feed responses ({len(tag_ids_from_feed)} total):")
        for name, tid in sorted(tag_ids_from_feed.items()):
            print(f"  {name!r}: {tid!r}")

        out_path = "scripts/qiandao_tag_ids.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(tag_ids_from_feed, f, ensure_ascii=False, indent=2)
        print(f"\nSaved to {out_path}")

        await browser.close()

asyncio.run(main())
