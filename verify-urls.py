#!/usr/bin/env python3
"""Verify placement URLs contain individual alumni-level data using scrapling"""

import asyncio
from scrapling import StealthyFetcher

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
        'url': 'https://www.american.edu/sis/phd/achievements-placements.cfm',
        'program': 'American University SIS International Relations PhD'
    },
    {
        'url': 'https://www.american.edu/cas/psychology/clinical-research/alums.cfm',
        'program': 'American University Clinical Psychology PhD'
    },
    {
        'url': 'https://www.american.edu/cas/anthropology/phd/students.cfm',
        'program': 'American University Anthropology PhD'
    },
    {
        'url': 'https://www.american.edu/cas/history/phd/',
        'program': 'American University History PhD'
    },
]

async def verify_url(fetcher, item):
    """Check if URL contains individual alumni placement info"""
    try:
        page = await fetcher.async_fetch(item['url'])
        text = page.get_all_text().lower()

        # Check for indicators of individual alumni data
        has_names = any(indicator in text for indicator in [
            'professor', 'assistant professor', 'associate professor',
            'postdoc', 'post-doc', 'postdoctoral',
            'phd', 'dr.', 'graduate', 'alumni', 'alum',
            'placement', 'position', 'appointed', 'joined'
        ])

        # Check for institution names (common placement destinations)
        has_institutions = any(inst in text for inst in [
            'university', 'college', 'institute', 'hospital',
            'bank', 'government', 'research'
        ])

        # Check for years (indicates when placements happened)
        import re
        has_years = bool(re.search(r'20[12][0-9]', text))

        is_valid = has_names and has_institutions and has_years

        print(f"\n{'✓' if is_valid else '✗'} {item['program']}")
        print(f"  URL: {item['url']}")
        print(f"  Has alumni indicators: {has_names}")
        print(f"  Has institution names: {has_institutions}")
        print(f"  Has year references: {has_years}")

        # Show a snippet of relevant content
        if 'placement' in text or 'alumni' in text:
            # Find a relevant section
            for line in page.get_all_text().split('\n'):
                if any(word in line.lower() for word in ['placement', 'position', 'professor', 'joined']):
                    if len(line.strip()) > 20:
                        print(f"  Sample: {line.strip()[:100]}...")
                        break

        return is_valid

    except Exception as e:
        print(f"\n✗ {item['program']}")
        print(f"  URL: {item['url']}")
        print(f"  Error: {str(e)}")
        return False

async def main():
    print("Verifying placement URLs for individual alumni-level data...\n")

    fetcher = StealthyFetcher()

    valid_count = 0
    for item in urls_to_verify:
        if await verify_url(fetcher, item):
            valid_count += 1

    print(f"\n\nSummary: {valid_count}/{len(urls_to_verify)} URLs verified")

if __name__ == '__main__':
    asyncio.run(main())
