#!/usr/bin/env python3
"""
Extract structured placement data from verified URLs.
Output JSON for review before database insertion.
"""

import asyncio
import json
import re
from scrapling.fetchers import PlayWrightFetcher

# Verified URLs with their source program info
SOURCES = [
    {
        'url': 'https://www.american.edu/cas/economics/phd/job-market-candidates.cfm',
        'program_name': 'Economics',
        'degree': 'PhD',
        'source_institution': 'American University',
        'source_institution_id': '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
        'program_id': '4e8f2e8b-6806-4602-8405-2050f3e8793b'
    },
    {
        'url': 'https://www.american.edu/soc/communication-studies/phd/achievements-and-placements.cfm',
        'program_name': 'Communication',
        'degree': 'PhD',
        'source_institution': 'American University',
        'source_institution_id': '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
        'program_id': '552124a7-c5ec-480d-807a-92cd26583a7e'
    },
    {
        'url': 'https://www.american.edu/cas/psychology/clinical-research/alums.cfm',
        'program_name': 'Clinical Psychology',
        'degree': 'PhD',
        'source_institution': 'American University',
        'source_institution_id': '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
        'program_id': '1e0f49da-a0fe-4802-95ec-d79ada0bef1b'
    },
    {
        'url': 'https://www.american.edu/sis/phd/achievements-placements.cfm',
        'program_name': 'International Relations',
        'degree': 'PhD',
        'source_institution': 'American University',
        'source_institution_id': '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
        'program_id': '64c32c73-7530-4cb3-8e0c-f1518c30bafd'
    },
    {
        'url': 'https://www.amse-aixmarseille.fr/en/study/phd/phd-placement',
        'program_name': 'Economics',
        'degree': 'PhD',
        'source_institution': 'Aix-Marseille University',
        'source_institution_id': 'eb322b5c-965a-45fe-8dbf-3635ea1fa972',
        'program_id': '9e18f0a1-8b9e-4195-b2ca-0d6528e4027d'
    },
]

def parse_placement_line(line):
    """
    Parse a line like:
    "Amy Burnett Cross: Postdoctoral Fellow, University of Alaska Anchorage"
    Returns: (name, position, institution) or None
    """
    # Common patterns
    patterns = [
        # "Name: Position, Institution"
        r'^([A-Z][a-zA-Z\s\.\-\']+?):\s*(.+?),\s*(.+)$',
        # "Name: Position at Institution"
        r'^([A-Z][a-zA-Z\s\.\-\']+?):\s*(.+?)\s+at\s+(.+)$',
        # "Dr. Name is Position at Institution"
        r'^Dr\.\s*([A-Z][a-zA-Z\s\.\-\']+?)\s+is\s+(?:a\s+|an\s+)?(.+?)\s+at\s+(.+)$',
        # "Name, Position, Institution"
        r'^([A-Z][a-zA-Z\s\.\-\']+?),\s*(.+?),\s*([A-Z].+)$',
    ]

    for pattern in patterns:
        match = re.match(pattern, line.strip())
        if match:
            name, position, institution = match.groups()
            # Clean up
            name = name.strip().rstrip(':,')
            position = position.strip().rstrip(',')
            institution = institution.strip().rstrip('.')

            # Filter out non-person entries
            if len(name) < 3 or len(name) > 50:
                continue
            if any(skip in name.lower() for skip in ['copyright', 'university', 'college', 'school', 'department']):
                continue

            return {
                'name': name,
                'position': position,
                'institution': institution
            }
    return None

async def extract_from_url(fetcher, source):
    """Extract placement data from a URL"""
    print(f"\nExtracting from: {source['url']}")

    try:
        page = await fetcher.async_fetch(source['url'], wait_selector='body', timeout=30000)
        text = page.get_all_text()

        placements = []
        lines = text.split('\n')

        for line in lines:
            line = line.strip()
            if len(line) < 20 or len(line) > 300:
                continue

            # Look for lines with placement-like patterns
            if ':' in line or ' at ' in line.lower():
                parsed = parse_placement_line(line)
                if parsed:
                    placements.append({
                        **parsed,
                        'source_program': source['program_name'],
                        'source_degree': source['degree'],
                        'source_institution': source['source_institution'],
                        'source_institution_id': source['source_institution_id'],
                        'program_id': source['program_id'],
                        'source_url': source['url']
                    })

        # Deduplicate by name
        seen_names = set()
        unique_placements = []
        for p in placements:
            name_key = p['name'].lower().strip()
            if name_key not in seen_names:
                seen_names.add(name_key)
                unique_placements.append(p)

        print(f"  Found {len(unique_placements)} unique placements")
        return unique_placements

    except Exception as e:
        print(f"  Error: {e}")
        return []

async def main():
    fetcher = PlayWrightFetcher()
    all_placements = []

    for source in SOURCES:
        placements = await extract_from_url(fetcher, source)
        all_placements.extend(placements)

    print(f"\n{'='*60}")
    print(f"TOTAL: {len(all_placements)} placements extracted")
    print('='*60)

    # Save to JSON for review
    output_file = 'extracted-placements.json'
    with open(output_file, 'w') as f:
        json.dump(all_placements, f, indent=2)
    print(f"\nSaved to {output_file}")

    # Print sample
    print("\nSample entries:")
    for p in all_placements[:10]:
        print(f"  - {p['name']}: {p['position']} @ {p['institution']}")
        print(f"    (from {p['source_degree']} in {p['source_program']} at {p['source_institution']})")

if __name__ == '__main__':
    asyncio.run(main())
