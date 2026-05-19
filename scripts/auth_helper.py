"""
auth_helper.py — Shared Playwright authentication for qiandao scrapers.

First run: opens a browser window for you to log in to qiandao.
           Saves session to scripts/qiandao_session.json.
Next runs:  loads the saved session silently (no browser window needed).
"""
import asyncio
import json
from pathlib import Path
from playwright.async_api import async_playwright

CATALOG_URL = (
    "https://qiandao.com/island/catalog"
    "?id=300231"
    "&navigationName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&tabName=%E6%89%BE%E5%89%A7%E6%9C%AC"
    "&title=%E6%89%BE%E5%89%A7%E6%9C%AC"
)

SESSION_PATH = Path(__file__).parent / "qiandao_session.json"

KEEP_HEADERS = [
    "x-request-timestamp", "x-request-sign", "x-request-sign-type",
    "x-request-sign-version", "x-request-package-sign-version",
    "x-request-package-id", "x-request-version", "x-client-package-id",
    "x-echoing-env", "accept", "content-type", "referer", "user-agent",
]


async def _try_capture(p, storage_state=None) -> dict:
    """Try to capture signed headers, optionally with saved session."""
    captured = {}
    headless = storage_state is not None  # headless if we have a saved session

    launch_kwargs = {}
    context_kwargs = {
        "user_agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        )
    }
    if storage_state:
        context_kwargs["storage_state"] = storage_state

    browser = await p.chromium.launch(headless=headless, **launch_kwargs)
    context = await browser.new_context(**context_kwargs)
    page = await context.new_page()

    async def on_request(request):
        if "ssr/spu/feed" in request.url and not captured:
            for k, v in request.headers.items():
                if k.lower() in KEEP_HEADERS:
                    captured[k.lower()] = v
            if captured:
                print(f"Captured {len(captured)} signed headers")

    page.on("request", on_request)

    if not headless:
        print("[INFO] Browser opened — please log in to qiandao.com if prompted.")
        print("[INFO] The catalog page will load automatically after login.")

    asyncio.ensure_future(
        page.goto(CATALOG_URL, wait_until="commit", timeout=60000)
    )

    wait_secs = 60 if headless else 120
    for i in range(wait_secs):
        if captured:
            break
        if not headless and i == 30 and not captured:
            print("[INFO] Still waiting... scroll the page or log in if needed.")
        await asyncio.sleep(1)

    if not captured:
        try:
            await page.evaluate("window.scrollBy(0, 500)")
        except Exception:
            pass
        await asyncio.sleep(5)

    # Save session state after successful capture (whether fresh or reused)
    if captured and not headless:
        try:
            state = await context.storage_state()
            SESSION_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2))
            print(f"[INFO] Session saved to {SESSION_PATH}")
            print("[INFO] Future runs will be headless (no browser window).")
        except Exception as e:
            print(f"[WARN] Could not save session: {e}")

    # Always save the signed headers so qiandao_lookup.py can reuse them
    if captured:
        signed_path = SESSION_PATH.parent / "qiandao_signed_headers.json"
        try:
            signed_path.write_text(json.dumps(captured, ensure_ascii=False, indent=2))
        except Exception:
            pass

    await browser.close()
    return captured


async def capture_signed_headers() -> dict:
    """
    Capture HMAC-signed headers from qiandao.

    - If qiandao_session.json exists: runs headlessly using saved session.
    - Otherwise: opens a browser window for manual login, then saves session.
    """
    async with async_playwright() as p:
        # Try with saved session first
        if SESSION_PATH.exists():
            print("[INFO] Found saved session, trying headless mode...")
            try:
                storage_state = json.loads(SESSION_PATH.read_text())
                headers = await _try_capture(p, storage_state=storage_state)
                if headers:
                    return headers
                print("[WARN] Saved session expired or invalid, opening browser...")
                SESSION_PATH.unlink(missing_ok=True)
            except Exception as e:
                print(f"[WARN] Failed to load session: {e}")

        # Fall back to manual login
        print("Loading catalog page to capture signed headers...")
        return await _try_capture(p, storage_state=None)
