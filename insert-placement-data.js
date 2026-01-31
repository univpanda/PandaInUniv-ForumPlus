const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });
const fs = require('fs');

async function insertPlacementData(jsonFile) {
  const data = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));

  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to database\n');

    const source = data.source;
    console.log(`Source: ${source.degree} in ${source.program_name} at ${source.institution}`);
    console.log(`Graduates to process: ${data.graduates.length}\n`);

    const names = data.graduates.map(g => g.name.toLowerCase());

    // Duplicate check: name + program_id + institution + year (±2)
    const existing = await client.query(`
      SELECT f.id as faculty_id, LOWER(f.name) as name, e.year
      FROM pt_faculty f
      JOIN pt_faculty_education e ON f.id = e.faculty_id
      WHERE LOWER(f.name) = ANY($1)
        AND e.program_id = $2
        AND e.institution_id = $3
    `, [names, source.program_id, source.institution_id]);

    // Map: name -> [{faculty_id, year}]
    const existingMap = new Map();
    for (const row of existing.rows) {
      if (!existingMap.has(row.name)) existingMap.set(row.name, []);
      existingMap.get(row.name).push({ faculty_id: row.faculty_id, year: row.year });
    }

    // Categorize
    const toSkip = [];
    const toInsert = [];

    for (const grad of data.graduates) {
      const nameKey = grad.name.toLowerCase();
      const matches = existingMap.get(nameKey);

      if (matches) {
        // Check if any match has close year (±2)
        const closeMatch = matches.find(m => Math.abs(m.year - grad.graduation_year) <= 2);
        if (closeMatch) {
          toSkip.push({ grad, faculty_id: closeMatch.faculty_id, reason: 'duplicate' });
        } else {
          // Same name + program + institution but year too different - could be different person
          toInsert.push(grad);
        }
      } else {
        toInsert.push(grad);
      }
    }

    console.log(`Skip (duplicate): ${toSkip.length}`);
    console.log(`Insert (new): ${toInsert.length}`);

    // Insert new faculty + education + career in batch
    if (toInsert.length > 0) {
      // 1. Insert faculty
      const fValues = toInsert.map((_, i) => `($${i * 2 + 1}, $${i * 2 + 2}, NOW())`).join(', ');
      const fParams = toInsert.flatMap(g => [g.name, g.placement?.position || null]);

      const fResult = await client.query(
        `INSERT INTO pt_faculty (name, designation, updated_at) VALUES ${fValues} RETURNING id, name`,
        fParams
      );
      const newFacultyMap = new Map(fResult.rows.map(r => [r.name.toLowerCase(), r.id]));
      console.log(`\n✓ Inserted ${fResult.rowCount} faculty`);

      // 2. Insert education
      const eValues = toInsert.map((_, i) => {
        const b = i * 7;
        return `($${b+1}, $${b+2}, $${b+3}, $${b+4}, $${b+5}, $${b+6}, $${b+7}, NOW())`;
      }).join(', ');
      const eParams = toInsert.flatMap(g => [
        newFacultyMap.get(g.name.toLowerCase()),
        source.degree,
        source.program_name,
        source.institution_id,
        g.graduation_year,
        source.program_id,
        g.advisor || null
      ]);

      await client.query(
        `INSERT INTO pt_faculty_education (faculty_id, degree, field, institution_id, year, program_id, advisor, updated_at)
         VALUES ${eValues}`,
        eParams
      );
      console.log(`✓ Inserted ${toInsert.length} education records`);

      // 3. Insert career (if placement available)
      const withPlacement = toInsert.filter(g => g.placement?.position && g.placement?.institution);
      if (withPlacement.length > 0) {
        const cValues = withPlacement.map((_, i) => {
          const b = i * 4;
          return `($${b+1}, $${b+2}, $${b+3}, $${b+4}, NOW())`;
        }).join(', ');
        const cParams = withPlacement.flatMap(g => [
          newFacultyMap.get(g.name.toLowerCase()),
          g.placement.position,
          g.placement.institution,
          g.graduation_year
        ]);

        await client.query(
          `INSERT INTO pt_faculty_career (faculty_id, designation, institution_name, year, updated_at)
           VALUES ${cValues}`,
          cParams
        );
        console.log(`✓ Inserted ${withPlacement.length} career records`);
      }

      // Show sample
      console.log('\nSample inserted:');
      toInsert.slice(0, 5).forEach(g => {
        console.log(`  ${g.name} (${g.graduation_year})`);
        if (g.placement?.position) console.log(`    → ${g.placement.position} at ${g.placement.institution}`);
      });
      if (toInsert.length > 5) console.log(`  ... and ${toInsert.length - 5} more`);
    }

    // Update last_parsed_at for the program
    await client.query(
      `UPDATE pt_academic_programs SET last_parsed_at = NOW() WHERE id = $1`,
      [source.program_id]
    );
    console.log(`✓ Updated last_parsed_at for program ${source.program_id}`);

    console.log('\n✓ Done!');

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

const jsonFile = process.argv[2] || 'placement-data.json';
console.log(`Processing: ${jsonFile}\n`);
insertPlacementData(jsonFile);
