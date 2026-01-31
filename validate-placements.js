const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });
const fs = require('fs');

// Manually curated valid placements from extracted data
const validPlacements = [
  // AU Economics PhD
  {
    name: 'Amy Burnett Cross',
    position: 'Postdoctoral Fellow',
    institution: 'University of Alaska Anchorage',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Tinatin Mumladze',
    position: 'Assistant Professor of Economics',
    institution: 'American University of Sharjah',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Lin Shi',
    position: 'Postdoctoral Fellow',
    institution: 'Boston University',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Danielle Wilson',
    position: 'Postdoctoral Fellow',
    institution: 'Columbia University',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Sarah Oliver',
    position: 'Economist',
    institution: 'U.S. Government Accountability Office',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Vasudeva Ramaswamy',
    position: 'Postdoctoral Fellow',
    institution: 'American University',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Hannah Randolph',
    position: 'Research Fellow',
    institution: 'University of Strathclyde',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  {
    name: 'Tanima Ahmed',
    position: 'Economist',
    institution: 'World Bank',
    source_program: 'Economics',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '4e8f2e8b-6806-4602-8405-2050f3e8793b'
  },
  // AU Clinical Psychology PhD
  {
    name: 'Mark L. Nelson',
    position: 'Associate Professor of Psychology',
    institution: 'Harrisburg Area Community College',
    source_program: 'Clinical Psychology',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '1e0f49da-a0fe-4802-95ec-d79ada0bef1b'
  },
  {
    name: 'Wilson McDermut',
    position: 'Associate Professor of Psychology',
    institution: "St. John's University",
    source_program: 'Clinical Psychology',
    source_degree: 'PhD',
    source_institution: 'American University',
    source_institution_id: '7b2afcb2-8f90-4981-92bc-eb3a5f15515a',
    program_id: '1e0f49da-a0fe-4802-95ec-d79ada0bef1b'
  }
];

async function validatePlacements() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();

    console.log('Validating placement data...\n');
    console.log('='.repeat(70));

    for (const p of validPlacements) {
      console.log(`\nPerson: ${p.name}`);
      console.log(`  Position: ${p.position}`);
      console.log(`  At: ${p.institution}`);
      console.log(`  PhD from: ${p.source_institution} (${p.source_program})`);

      // Check if person already exists in pt_faculty
      const existingFaculty = await client.query(
        `SELECT id, name, designation, institution_id
         FROM pt_faculty
         WHERE LOWER(name) LIKE $1 OR LOWER(name) LIKE $2`,
        [`%${p.name.toLowerCase()}%`, `%${p.name.split(' ').pop().toLowerCase()}%`]
      );

      if (existingFaculty.rowCount > 0) {
        console.log(`  ⚠️  POSSIBLE MATCH in pt_faculty:`);
        existingFaculty.rows.forEach(f => {
          console.log(`      - ${f.name} (id: ${f.id.substring(0,8)}...)`);
        });
      } else {
        console.log(`  ✓ Not found in pt_faculty (new entry)`);
      }

      // Check if placement institution exists
      const instSearch = p.institution.split(' ').slice(0, 3).join(' ');
      const existingInst = await client.query(
        `SELECT id, COALESCE(english_name, official_name) as name
         FROM pt_institute
         WHERE LOWER(COALESCE(english_name, official_name)) LIKE $1
         LIMIT 5`,
        [`%${instSearch.toLowerCase()}%`]
      );

      if (existingInst.rowCount > 0) {
        console.log(`  ✓ Institution match found:`);
        existingInst.rows.forEach(i => {
          console.log(`      - ${i.name} (id: ${i.id.substring(0,20)}...)`);
        });
      } else {
        console.log(`  ⚠️  Institution NOT FOUND: "${p.institution}"`);
      }
    }

    console.log('\n' + '='.repeat(70));
    console.log(`Total valid placements to process: ${validPlacements.length}`);

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

validatePlacements();
