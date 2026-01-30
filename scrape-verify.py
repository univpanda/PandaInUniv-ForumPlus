#!/usr/bin/env python3
"""Scrape and verify placement URLs using scrapling"""

import asyncio
from scrapling.fetchers import PlayWrightFetcher

async def scrape_url(url, program_name):
    """Scrape URL and extract alumni placement data"""
    fetcher = PlayWrightFetcher()
    try:
        page = await fetcher.async_fetch(url, wait_selector='body', timeout=30000)
        text = page.get_all_text()

        print(f"\n{'='*70}")
        print(f"PROGRAM: {program_name}")
        print(f"URL: {url}")
        print(f"{'='*70}")

        # Find relevant sections containing placement info
        lines = text.split('\n')
        relevant_lines = []

        keywords = ['professor', 'postdoc', 'economist', 'researcher', 'analyst',
                   'director', 'manager', 'fellow', 'scientist', 'phd', 'dr.',
                   'university', 'college', 'institute', 'bank', 'government',
                   'placement', 'position', 'joined', 'hired', 'appointed',
                   '2020', '2021', '2022', '2023', '2024', '2025']

        for i, line in enumerate(lines):
            line_lower = line.lower().strip()
            if len(line_lower) > 30:  # Skip short lines
                if any(kw in line_lower for kw in keywords):
                    relevant_lines.append(line.strip())

        if relevant_lines:
            print("\nRELEVANT CONTENT (alumni/placement info):")
            print("-" * 50)
            for line in relevant_lines[:30]:  # Show first 30 relevant lines
                print(f"  {line[:120]}")

            # Check if this has individual-level data
            has_individuals = any(
                word in text.lower() for word in
                ['assistant professor', 'associate professor', 'postdoc', 'economist at', 'joined', 'hired']
            )
            print(f"\n✓ HAS INDIVIDUAL ALUMNI DATA: {has_individuals}")
            return has_individuals
        else:
            print("\n✗ NO PLACEMENT DATA FOUND")
            return False

    except Exception as e:
        print(f"\n✗ ERROR: {e}")
        return False

async def main():
    urls = [
        ("https://www.american.edu/cas/economics/phd/job-market-candidates.cfm", "AU Economics PhD"),
        ("https://www.american.edu/soc/communication-studies/phd/achievements-and-placements.cfm", "AU Communication PhD"),
        ("https://www.american.edu/cas/psychology/clinical-research/alums.cfm", "AU Clinical Psychology PhD"),
        ("https://www.american.edu/sis/phd/achievements-placements.cfm", "AU SIS Int'l Relations PhD"),
        ("https://www.amse-aixmarseille.fr/en/study/phd/phd-placement", "Aix-Marseille Economics PhD"),
    ]

    results = []
    for url, name in urls:
        result = await scrape_url(url, name)
        results.append((name, url, result))

    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    for name, url, valid in results:
        status = "✓ VALID" if valid else "✗ INVALID"
        print(f"{status}: {name}")
        print(f"         {url}")

if __name__ == '__main__':
    asyncio.run(main())
