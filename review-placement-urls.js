const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function reviewPlacementUrls() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();

    // Get all programs with placement_urls
    const result = await client.query(`
      SELECT
        p.id as program_id,
        p.program_name,
        p.degree,
        p.placement_url,
        d.department,
        d.id as department_id,
        s.school,
        s.id as school_id,
        i.id as institution_id,
        COALESCE(i.english_name, i.official_name) as institution
      FROM pt_academic_programs p
      LEFT JOIN pt_department d ON p.department_id = d.id
      LEFT JOIN pt_school s ON d.school_id = s.id
      LEFT JOIN pt_institute i ON s.institution_id = i.id
      WHERE p.placement_url IS NOT NULL
        AND array_length(p.placement_url, 1) > 0
      ORDER BY institution, p.program_name
    `);

    console.log(`Found ${result.rowCount} programs with placement_url:\n`);

    result.rows.forEach((row, idx) => {
      console.log(`${idx + 1}. ${row.institution}`);
      console.log(`   Program: ${row.degree} in ${row.program_name}`);
      console.log(`   Program ID: ${row.program_id}`);
      console.log(`   Department ID: ${row.department_id}`);
      console.log(`   Institution ID: ${row.institution_id}`);
      console.log(`   URLs: ${JSON.stringify(row.placement_url)}`);
      console.log('');
    });

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

reviewPlacementUrls();
