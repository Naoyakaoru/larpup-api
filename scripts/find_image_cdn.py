"""Load the qiandao catalog page and find the real image CDN base URL."""
import asyncio
import re
from playwright.async_api import async_playwright

CATALOG_URL = (
    "https://qiandao.com/island/catalog"
    "?id=300231&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC&title=%E6%89%BE%E5%89%A7%E6%9C%AC"
)

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ))
        page = await context.new_page()

        image_urls = set()

        async def on_response(response):
            url = response.url
            if re.search(r"\.(jpg|jpeg|png|webp)", url, re.I):
                image_urls.add(url)

        page.on("response", on_response)
        await page.goto(CATALOG_URL, wait_until="domcontentloaded", timeout=60000)
        await asyncio.sleep(5)

        print("Image URLs captured:")
        for url in sorted(image_urls)[:20]:
            print(" ", url)

        await browser.close()

asyncio.run(main())
