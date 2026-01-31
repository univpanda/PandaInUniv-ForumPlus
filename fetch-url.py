#!/usr/bin/env python3
"""Fetch a URL and save raw content - with expand/interaction support"""

import asyncio
import sys
from scrapling.fetchers import PlayWrightFetcher

async def fetch_scrapling(url):
    """Use scrapling's PlayWrightFetcher (handles anti-bot well)"""
    print(f"Fetching (scrapling): {url}")
    fetcher = PlayWrightFetcher()
    page = await fetcher.async_fetch(url, wait_selector='body', timeout=60000)
    return page.get_all_text()

async def fetch_with_expand(url):
    """Use Playwright directly for sites needing expand/click actions"""
    from playwright.async_api import async_playwright

    print(f"Fetching (with expand): {url}")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        await page.goto(url, timeout=60000, wait_until='domcontentloaded')
        await asyncio.sleep(3)

        # Try to click "Expand all" if it exists
        try:
            expand_btn = page.locator('text=Expand all').first
            if await expand_btn.is_visible():
                print("Found 'Expand all' button, clicking...")
                await expand_btn.click()
                await asyncio.sleep(2)
        except:
            pass

        # Try other common expand patterns
        try:
            toggles = page.locator('[aria-expanded="false"]')
            count = await toggles.count()
            if count > 0:
                print(f"Found {count} collapsed sections, expanding...")
                for i in range(min(count, 20)):
                    try:
                        await toggles.nth(i).click()
                        await asyncio.sleep(0.3)
                    except:
                        pass
        except:
            pass

        await asyncio.sleep(1)

        # Get both innerText (visible) and textContent (all including hidden)
        inner_text = await page.inner_text('body')
        text_content = await page.evaluate('document.body.textContent')

        # If textContent is significantly larger, page has hidden content - use textContent
        if len(text_content) > len(inner_text) * 1.5:
            print(f"Hidden content detected: innerText={len(inner_text)}, textContent={len(text_content)}")
            text = text_content
        else:
            text = inner_text

        await browser.close()

    return text

async def fetch(url, mode='auto'):
    """
    Fetch URL content
    mode: 'auto', 'scrapling', 'expand'
    - auto: try expand first, if blocked try scrapling
    - scrapling: use scrapling only (good for anti-bot)
    - expand: use playwright with expand (good for accordions)
    """
    text = None

    if mode == 'scrapling':
        text = await fetch_scrapling(url)
    elif mode == 'expand':
        text = await fetch_with_expand(url)
    else:  # auto - try expand first, fallback to scrapling
        try:
            text = await fetch_with_expand(url)
            # Check if blocked
            if 'cloudflare' in text.lower() or 'verify you are human' in text.lower() or len(text) < 500:
                print("Detected block, retrying with scrapling...")
                text = await fetch_scrapling(url)
        except Exception as e:
            print(f"Expand mode failed: {e}, trying scrapling...")
            text = await fetch_scrapling(url)

    with open('raw-content.txt', 'w') as f:
        f.write(text)

    print(f"Saved to raw-content.txt ({len(text)} chars)")
    print("\n" + "="*70)
    print(text[:3000])
    print("\n... (truncated)")

if __name__ == '__main__':
    url = sys.argv[1] if len(sys.argv) > 1 else 'https://www.american.edu/cas/economics/phd/job-market-candidates.cfm'
    mode = sys.argv[2] if len(sys.argv) > 2 else 'auto'
    asyncio.run(fetch(url, mode))
