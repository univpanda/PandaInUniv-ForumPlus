const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function queryMissingUrls() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();

    const result = await client.query(`
      SELECT
        p.id,
        p.program_name,
        p.degree,
        p.placement_url,
        d.department,
        s.school,
        COALESCE(i.english_name, i.official_name) as institution
      FROM pt_academic_programs p
      LEFT JOIN pt_department d ON p.department_id = d.id
      LEFT JOIN pt_school s ON d.school_id = s.id
      LEFT JOIN pt_institute i ON s.institution_id = i.id
      WHERE p.placement_url IS NULL OR array_length(p.placement_url, 1) IS NULL
      ORDER BY institution, s.school, d.department, p.program_name
      LIMIT 50
    `);

    console.log(`Found ${result.rowCount} programs with missing placement_url:\n`);
    result.rows.forEach((row, idx) => {
      console.log(`${idx + 1}. ${row.institution} > ${row.school} > ${row.department}`);
      console.log(`   Program: ${row.degree} in ${row.program_name}`);
      console.log(`   ID: ${row.id}\n`);
    });

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

queryMissingUrls();
