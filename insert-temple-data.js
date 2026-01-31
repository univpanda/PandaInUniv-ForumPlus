const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });
const fs = require('fs');

async function insertTempleData() {
  const data = JSON.parse(fs.readFileSync('placement-data-temple-all.json', 'utf8'));

  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  console.log('Connected to database\n');

  const institutionId = data.institution_id;
  const programs = data.programs;

  // Group graduates by department
  const byDept = {};
  for (const g of data.graduates) {
    if (!byDept[g.dept]) byDept[g.dept] = [];
    byDept[g.dept].push(g);
  }

  let totalInserted = 0;
  let totalSkipped = 0;

  for (const [dept, grads] of Object.entries(byDept)) {
    const programId = programs[dept];
    if (!programId) {
      console.log(`Unknown department: ${dept}`);
      continue;
    }

    console.log(`\n${dept}: ${grads.length} graduates`);

    // Get existing names for this program
    const names = grads.map(g => g.name.toLowerCase());
    const existing = await client.query(`
      SELECT f.id as faculty_id, LOWER(f.name) as name, e.year
      FROM pt_faculty f
      JOIN pt_faculty_education e ON f.id = e.faculty_id
      WHERE LOWER(f.name) = ANY($1)
        AND e.program_id = $2
        AND e.institution_id = $3
    `, [names, programId, institutionId]);

    const existingMap = new Map();
    for (const row of existing.rows) {
      if (!existingMap.has(row.name)) existingMap.set(row.name, []);
      existingMap.get(row.name).push({ faculty_id: row.faculty_id, year: row.year });
    }

    const toInsert = [];
    for (const g of grads) {
      const nameKey = g.name.toLowerCase();
      const matches = existingMap.get(nameKey);
      if (matches) {
        const closeMatch = matches.find(m => Math.abs(m.year - g.year) <= 2);
        if (closeMatch) {
          totalSkipped++;
          continue;
        }
      }
      toInsert.push(g);
    }

    if (toInsert.length === 0) {
      console.log(`  Skipped all (duplicates)`);
      continue;
    }

    // Insert faculty
    const fValues = toInsert.map((_, i) => `($${i * 2 + 1}, $${i * 2 + 2}, NOW())`).join(', ');
    const fParams = toInsert.flatMap(g => [g.name, null]);
    const fResult = await client.query(
      `INSERT INTO pt_faculty (name, designation, updated_at) VALUES ${fValues} RETURNING id, name`,
      fParams
    );
    const newFacultyMap = new Map(fResult.rows.map(r => [r.name.toLowerCase(), r.id]));

    // Insert education
    const eValues = toInsert.map((_, i) => {
      const b = i * 6;
      return `($${b+1}, $${b+2}, $${b+3}, $${b+4}, $${b+5}, $${b+6}, NOW())`;
    }).join(', ');
    const eParams = toInsert.flatMap(g => [
      newFacultyMap.get(g.name.toLowerCase()),
      'PhD',
      dept,
      institutionId,
      g.year,
      programId
    ]);
    await client.query(
      `INSERT INTO pt_faculty_education (faculty_id, degree, field, institution_id, year, program_id, updated_at) VALUES ${eValues}`,
      eParams
    );

    // Insert career
    const withPlacement = toInsert.filter(g => g.placement);
    if (withPlacement.length > 0) {
      const cValues = withPlacement.map((_, i) => {
        const b = i * 4;
        return `($${b+1}, $${b+2}, $${b+3}, $${b+4}, NOW())`;
      }).join(', ');
      const cParams = withPlacement.flatMap(g => [
        newFacultyMap.get(g.name.toLowerCase()),
        'Faculty',
        g.placement,
        g.year
      ]);
      await client.query(
        `INSERT INTO pt_faculty_career (faculty_id, designation, institution_name, year, updated_at) VALUES ${cValues}`,
        cParams
      );
    }

    console.log(`  Inserted: ${toInsert.length}`);
    totalInserted += toInsert.length;

    // Update last_parsed_at
    await client.query(`UPDATE pt_academic_programs SET last_parsed_at = NOW() WHERE id = $1`, [programId]);
  }

  console.log(`\n========================================`);
  console.log(`Total inserted: ${totalInserted}`);
  console.log(`Total skipped: ${totalSkipped}`);

  await client.end();
}

insertTempleData();
