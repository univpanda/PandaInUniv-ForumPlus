#!/usr/bin/env python3
"""Verify remaining URLs"""

import asyncio
from scrapling.fetchers import PlayWrightFetcher

async def scrape_url(url, program_name):
    fetcher = PlayWrightFetcher()
    try:
        page = await fetcher.async_fetch(url, wait_selector='body', timeout=30000)
        text = page.get_all_text()

        print(f"\n{'='*70}")
        print(f"PROGRAM: {program_name}")
        print(f"URL: {url}")
        print(f"Content length: {len(text)} chars")
        print(f"{'='*70}")

        # Look for individual placement data
        keywords = ['professor', 'postdoc', 'alumni', 'graduate', 'placement',
                   'position', 'joined', 'university', 'college', 'hired',
                   '2020', '2021', '2022', '2023', '2024', '2025']

        lines = text.split('\n')
        relevant = []
        for line in lines:
            if len(line.strip()) > 30:
                if any(kw in line.lower() for kw in keywords):
                    relevant.append(line.strip())

        if relevant:
            print("\nRELEVANT CONTENT:")
            print("-" * 50)
            for line in relevant[:25]:
                print(f"  {line[:120]}")

        # Check for individual names with positions
        has_individuals = any(phrase in text.lower() for phrase in [
            'assistant professor', 'associate professor', 'postdoc',
            'went to', 'joined', 'is now', 'works at', 'hired'
        ])

        print(f"\n{'✓' if has_individuals else '✗'} HAS INDIVIDUAL ALUMNI DATA: {has_individuals}")
        return has_individuals

    except Exception as e:
        print(f"ERROR: {e}")
        return False

async def main():
    urls = [
        ("https://www.american.edu/cas/history/phd/", "AU History PhD"),
        ("https://www.american.edu/cas/anthropology/phd/students.cfm", "AU Anthropology PhD Students"),
        ("https://www.american.edu/spa/news/phd-placements-05062016.cfm", "AU SPA PhD Placements"),
        ("https://www.american.edu/spa/alumni/notable-alumni.cfm", "AU SPA Notable Alumni"),
    ]

    for url, name in urls:
        await scrape_url(url, name)

if __name__ == '__main__':
    asyncio.run(main())
