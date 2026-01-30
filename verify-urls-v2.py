#!/usr/bin/env python3
"""Verify placement URLs using scrapling with proper JS rendering"""

import asyncio
from scrapling.fetchers import PlayWrightFetcher

urls_to_verify = [
    {
        'url': 'https://www.american.edu/cas/economics/phd/job-market-candidates.cfm',
        'program': 'American University Economics PhD'
    },
    {
        'url': 'https://www.american.edu/soc/communication-studies/phd/achievements-and-placements.cfm',
        'program': 'American University Communication PhD'
    },
    {
        'url': 'https://www.american.edu/cas/psychology/clinical-research/alums.cfm',
        'program': 'American University Clinical Psychology PhD'
    },
]

async def verify_url(fetcher, item):
    """Check if URL contains individual alumni placement info"""
    try:
        page = await fetcher.async_fetch(item['url'], wait_selector='body', timeout=30000)
        text = page.get_all_text()

        print(f"\n{'='*60}")
        print(f"Program: {item['program']}")
        print(f"URL: {item['url']}")
        print(f"Content length: {len(text)} chars")
        print(f"\nFirst 1500 characters:")
        print("-"*40)
        print(text[:1500] if text else "NO CONTENT")
        print("-"*40)

        # Check for alumni placement indicators
        text_lower = text.lower()
        has_placements = any(word in text_lower for word in [
            'placement', 'placed', 'appointed', 'joined', 'hired',
            'assistant professor', 'associate professor', 'postdoc'
        ])

        print(f"\nHas placement indicators: {has_placements}")

        return has_placements

    except Exception as e:
        print(f"\n✗ {item['program']}")
        print(f"  Error: {str(e)}")
        return False

async def main():
    print("Verifying placement URLs with JavaScript rendering...\n")

    fetcher = PlayWrightFetcher()

    for item in urls_to_verify:
        await verify_url(fetcher, item)

if __name__ == '__main__':
    asyncio.run(main())
