#!/usr/bin/env python3
"""
Fetch and extract placement data from a single URL.
Save to JSON in a format ready for database insertion.

Minimum required: name + program + university
Optional: year, placement (position + institution), advisor, thesis
"""

import asyncio
import json
import re
from scrapling.fetchers import PlayWrightFetcher

# Source program info
SOURCE = {
    'url': 'https://www.amse-aixmarseille.fr/en/study/phd/phd-placement',
    'program_name': 'Economics',
    'degree': 'PhD',
    'source_institution': 'Aix-Marseille University',
    'source_institution_id': 'eb322b5c-965a-45fe-8dbf-3635ea1fa972',
    'program_id': '9e18f0a1-8b9e-4195-b2ca-0d6528e4027d'
}

def parse_graduates(text):
    """Parse graduate names and years from text content"""
    graduates = []
    lines = text.split('\n')

    current_year = None

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Check if line is a year (4 digits)
        if re.match(r'^20[12][0-9]$', line):
            current_year = int(line)
            continue

        # Skip navigation/menu items and short lines
        if len(line) < 3 or len(line) > 100:
            continue
        if line.lower() in ['youtube', 'linkedin', 'bluesky', 'fr', 'en', 'events', 'people',
                            'research', 'study', 'contact us', 'about us', 'news', 'press',
                            'job market', 'see candidates', 'customize', 'decline', 'accept']:
            continue
        if any(skip in line.lower() for skip in ['skip to', 'cookie', 'legal notice', 'intranet',
                                                   'working papers', 'newsletter', 'departments',
                                                   'publications', 'grants', 'phd program',
                                                   'master', 'how to apply', 'visiting', 'courses']):
            continue

        # If we have a current year and line looks like a name
        if current_year and re.match(r'^[A-ZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ]', line):
            # Extract name (remove parenthetical notes like "AMSE 4th year PhD grant")
            name = re.sub(r'\s*\([^)]+\)\s*$', '', line).strip()

            # Extract any note in parentheses
            note_match = re.search(r'\(([^)]+)\)', line)
            note = note_match.group(1) if note_match else None

            if len(name) >= 3 and ' ' in name:  # Must have at least first and last name
                graduates.append({
                    'name': name,
                    'graduation_year': current_year,
                    'note': note,
                    'placement': {
                        'position': None,
                        'institution': None,
                        'institution_id': None
                    },
                    'advisor': None,
                    'thesis_title': None
                })

    return graduates

async def fetch_and_extract():
    fetcher = PlayWrightFetcher()

    print(f"Fetching: {SOURCE['url']}")
    page = await fetcher.async_fetch(SOURCE['url'], wait_selector='body', timeout=30000)
    text = page.get_all_text()

    print(f"Content length: {len(text)} chars")

    # Parse graduates
    graduates = parse_graduates(text)

    # Build output structure
    output = {
        'source': {
            'url': SOURCE['url'],
            'program_name': SOURCE['program_name'],
            'degree': SOURCE['degree'],
            'institution': SOURCE['source_institution'],
            'institution_id': SOURCE['source_institution_id'],
            'program_id': SOURCE['program_id']
        },
        'extraction_date': '2026-01-30',
        'graduates': graduates
    }

    # Save to JSON
    output_file = 'placement-data-amse-econ.json'
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nExtracted {len(graduates)} graduates")
    print(f"Saved to {output_file}")

    # Print summary by year
    years = {}
    for g in graduates:
        y = g['graduation_year']
        years[y] = years.get(y, 0) + 1

    print("\nBy year:")
    for y in sorted(years.keys(), reverse=True):
        print(f"  {y}: {years[y]} graduates")

    # Print sample
    print("\nSample entries:")
    for g in graduates[:5]:
        print(f"  - {g['name']} ({g['graduation_year']})")

if __name__ == '__main__':
    asyncio.run(fetch_and_extract())
