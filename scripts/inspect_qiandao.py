"""
Step 1: Intercept XHR/fetch requests on qiandao catalog page.
Run this to find the underlying API endpoint, params, and auth headers.
"""
import json
import asyncio
from playwright.async_api import async_playwright

URL = "https://qiandao.com/island/catalog?id=300231&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC&title=%E6%89%BE%E5%89%A7%E6%9C%AC"

TARGET = "ssr/spu/feed"

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        async def on_request(request):
            if TARGET in request.url:
                print(f"\n{'='*60}")
                print(f"[REQUEST] {request.method} {request.url}")
                print(f"Headers: {json.dumps(dict(request.headers), ensure_ascii=False, indent=2)}")
                if request.post_data:
                    print(f"Body: {request.post_data[:2000]}")

        async def on_response(response):
            if TARGET in response.url:
                try:
                    body = await response.json()
                    print(f"\n[RESPONSE] status={response.status}")
                    print(f"Body: {json.dumps(body, ensure_ascii=False)[:2000]}")
                except Exception:
                    pass

        page.on("request", on_request)
        page.on("response", on_response)

        print(f"Loading: {URL}")
        try:
            await page.goto(URL, wait_until="domcontentloaded", timeout=30000)
        except Exception as e:
            print(f"Page load warning: {e}")

        for _ in range(5):
            await page.evaluate("window.scrollBy(0, 600)")
            await asyncio.sleep(1.5)

        await asyncio.sleep(3)
        await browser.close()

asyncio.run(main())
