const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

// Placement URLs found via web search - these contain individual alumni-level placement data
const placements = [
  {
    id: '4e8f2e8b-6806-4602-8405-2050f3e8793b',
    description: 'American University Economics PhD',
    urls: ['https://www.american.edu/cas/economics/phd/job-market-candidates.cfm']
  },
  {
    id: '552124a7-c5ec-480d-807a-92cd26583a7e',
    description: 'American University Communication PhD',
    urls: ['https://www.american.edu/soc/communication-studies/phd/achievements-and-placements.cfm']
  },
  {
    id: '64c32c73-7530-4cb3-8e0c-f1518c30bafd',
    description: 'American University SIS International Relations PhD',
    urls: ['https://www.american.edu/sis/phd/achievements-placements.cfm']
  },
  {
    id: '4af755cd-1afd-42ca-ba43-24f1c1f0265b',
    description: 'American University Anthropology PhD',
    urls: ['https://www.american.edu/cas/anthropology/phd/students.cfm']
  },
  {
    id: '5b905192-89c8-4740-8818-ab6d557567d9',
    description: 'American University History PhD',
    urls: ['https://www.american.edu/cas/history/phd/']
  },
  {
    id: '9e18f0a1-8b9e-4195-b2ca-0d6528e4027d',
    description: 'Aix-Marseille Economics PhD',
    urls: ['https://www.amse-aixmarseille.fr/en/study/phd/phd-placement']
  },
  {
    id: '4fb31ac9-b0ed-4033-ab01-3ddf58694c16',
    description: 'Aix-Marseille Finance PhD',
    urls: ['https://www.amse-aixmarseille.fr/en/study/phd/phd-placement']
  },
  // New additions
  {
    id: '1e0f49da-a0fe-4802-95ec-d79ada0bef1b',
    description: 'American University Clinical Psychology PhD',
    urls: ['https://www.american.edu/cas/psychology/clinical-research/alums.cfm']
  },
  {
    id: '0e70ddce-464f-4889-8eca-10769ce18ab8',
    description: 'American University Behavior Cognition Neuroscience PhD',
    urls: ['https://www.american.edu/cas/psychology/clinical-research/alums.cfm']
  },
  {
    id: '70d0566b-afc3-4ac7-bd86-d6beaac2bab3',
    description: 'American University Public Administration PhD',
    urls: ['https://www.american.edu/spa/news/phd-placements-05062016.cfm']
  },
  {
    id: '62b49c35-d626-4f58-91ec-44e5b4f96d51',
    description: 'American University Political Science PhD',
    urls: ['https://www.american.edu/spa/news/phd-placements-05062016.cfm']
  },
  {
    id: '1a91fc6c-039d-4dbf-859f-013ea8166ec6',
    description: 'American University Justice Law Criminology PhD',
    urls: ['https://www.american.edu/spa/alumni/notable-alumni.cfm']
  },
  {
    id: '82a327bd-1c1b-4fd8-9e0a-27df946ac05a',
    description: 'American University Education Policy PhD',
    urls: ['https://www.american.edu/spa/alumni/notable-alumni.cfm']
  },
  {
    id: '883db588-e6fb-4f1b-b7cf-fe24b2366ef6',
    description: 'American University EdD Education',
    urls: ['https://www.american.edu/spa/alumni/notable-alumni.cfm']
  }
];

async function updatePlacementUrls() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to database\n');

    for (const placement of placements) {
      const result = await client.query(
        `UPDATE pt_academic_programs
         SET placement_url = $1, updated_at = NOW()
         WHERE id = $2
         RETURNING id, program_name, degree`,
        [placement.urls, placement.id]
      );

      if (result.rowCount > 0) {
        const row = result.rows[0];
        console.log(`✓ Updated: ${row.degree} in ${row.program_name}`);
        console.log(`  URL: ${placement.urls[0]}\n`);
      } else {
        console.log(`✗ Not found: ${placement.description} (${placement.id})\n`);
      }
    }

    console.log(`\nDone! Updated ${placements.length} programs.`);

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

updatePlacementUrls();
