const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

// AMSE placement data with positions
const placements = [
  // 2025
  {name: "Anastasiia Antonova", year: 2025, position: "Economist", institution: "Bank of Canada"},
  {name: "Guillaume Bataille", year: 2025, position: "Post-doc", institution: "University of Luxembourg"},
  {name: "Leonard le Roux", year: 2025, position: "Post-doc", institution: "International Finance Corporation (World Bank Group)"},
  {name: "Santiago Lopez Cantor", year: 2025, position: "Teaching fellow (ATER)", institution: "Aix-Marseille Université"},
  {name: "Kohmei Makihara", year: 2025, position: "Post-doc", institution: "University of Copenhagen"},
  {name: "Mykhailo Matvieiev", year: 2025, position: "Economist", institution: "Bank of Canada"},
  {name: "Karine Moukaddem", year: 2025, position: "Post-doc", institution: "UCLouvain"},
  {name: "Inès Mourelon", year: 2025, position: "Post-doc", institution: "University of Bologna"},
  {name: "Ernesto Ugolini", year: 2025, position: "Teaching fellow (ATER)", institution: "Aix-Marseille Université"},
  {name: "Nathan Vieira", year: 2025, position: "Teaching fellow (ATER)", institution: "Université Grenoble Alpes"},
  // 2024
  {name: "Claire Alestra", year: 2024, position: "Postdoctoral fellow", institution: "PSE"},
  {name: "Daniela Arlia", year: 2024, position: "Economist", institution: "European Commission"},
  {name: "Johanne Bacheron", year: 2024, position: "Postdoctoral fellow", institution: "University degli studi di Torino"},
  {name: "Marie Beigelman", year: 2024, position: "Assistant professor", institution: "King's College London"},
  {name: "Tizié Bene", year: 2024, position: "Postdoctoral fellow", institution: "NYUAD"},
  {name: "Camille Hainnaux", year: 2024, position: "Postdoctoral fellow", institution: "University of Helsinki"},
  {name: "Jan-Luca Hennig", year: 2024, position: "Assistant professor", institution: "Universitat Autonoma de Barcelona"},
  {name: "Daniela Horta Saenz", year: 2024, position: "Postdoctoral fellow", institution: "NHH Bergen"},
  {name: "Bertille Picard", year: 2024, position: "Assistant professor", institution: "ENSAI"},
  {name: "Jade Ponsard", year: 2024, position: "Postdoctoral fellow", institution: "ENS Lyon"},
  {name: "Tom Raster", year: 2024, position: "Assistant professor", institution: "LSE"},
  {name: "Sofia Ruiz Palazuelos", year: 2024, position: "Assistant professor", institution: "University of Navarra"},
  {name: "Matteo Sestito", year: 2024, position: "Postdoctoral fellow", institution: "University of Lausanne"},
  {name: "Mathias Silva Vazquez", year: 2024, position: "Postdoctoral fellow", institution: "University of Tor Vergata"},
  {name: "Valentin Tissot", year: 2024, position: "Postdoctoral fellow", institution: "University of Bordeaux"},
  {name: "Priyam Verma", year: 2024, position: "Assistant professor", institution: "Ashoka University"},
  {name: "Sarah Vincent", year: 2024, position: "Postdoctoral fellow", institution: "Boston University"},
  // 2023
  {name: "Elie Vidal Naquet", year: 2023, position: "Postdoctoral fellow", institution: "HEC Paris"},
  {name: "Georgios Angelis", year: 2023, position: "Assistant professor", institution: "University of Glasgow"},
  {name: "Dallal Bendjellal", year: 2023, position: "Economist", institution: "IMF"},
  {name: "Marion Coste", year: 2023, position: "Postdoctoral fellow", institution: "IRD"},
  {name: "Neha Deopa", year: 2023, position: "Assistant professor", institution: "Exeter University"},
  {name: "Kenza Elass", year: 2023, position: "Postdoctoral fellow", institution: "Bocconi University"},
  {name: "Phoebe Ishak", year: 2023, position: "Economist", institution: "World Bank"},
  {name: "Suzanna Khalifa", year: 2023, position: "Assistant professor", institution: "Sciences Po Paris"},
  {name: "Nandeeta Neerunjun", year: 2023, position: "Assistant Professor with tenure", institution: "Université Grenoble Alpes"},
  {name: "Manuel Staab", year: 2023, position: "Assistant professor", institution: "Queensland University"},
  {name: "Morten Stostad", year: 2023, position: "Postdoctoral fellow", institution: "Norwegian School of Economics"},
  {name: "Carolina Ulloa Suarez", year: 2023, position: "Consultant", institution: "Inter-American Development Bank"},
  // 2022
  {name: "Yevgeny Tsodikovich", year: 2022, position: "Postdoctoral fellow", institution: "Bar Ilan University"},
  {name: "Kathia Bahloul", year: 2022, position: "Assistant professor", institution: "United Arab Emirates University"},
  {name: "Stéphane Benveniste", year: 2022, position: "Postdoctoral fellow", institution: "INED"},
  {name: "Guillaume Bérard", year: 2022, position: "Research associate", institution: "LISER"},
  {name: "Anushka Chawla", year: 2022, position: "Investment and impact manager", institution: "AFD"},
  {name: "Lisa Kerdelhué", year: 2022, position: "Economist", institution: "Banque de France"},
  {name: "Melina London", year: 2022, position: "Economist", institution: "European Commission"},
  {name: "Pavel Molchanov", year: 2022, position: "Postdoctoral fellow", institution: "HSE"},
  {name: "Fabien Petit", year: 2022, position: "Postdoctoral fellow", institution: "University of Sussex"},
  {name: "Julieta Peveri", year: 2022, position: "Postdoctoral fellow", institution: "ENS Lyon"},
  {name: "Meryem Rhouzlane", year: 2022, position: "Economist", institution: "IMF"},
  // 2021
  {name: "Shahir Safi", year: 2021, position: "Postdoctoral fellow", institution: "Concordia University"},
  {name: "Anna Belianska", year: 2021, position: "Economist", institution: "IMF"},
  {name: "Bjoern Brey", year: 2021, position: "Postdoctoral fellow", institution: "Université libre de Bruxelles"},
  {name: "Barbara Castillo Rico", year: 2021, position: "Head of Economic Studies", institution: "Meilleurs Agents"},
  {name: "Loann Desboulets", year: 2021, position: "Data scientist", institution: "Cite Gestion"},
  {name: "Estefania Galvan", year: 2021, position: "Lecturer", institution: "Universidad de la Republica"},
  {name: "Kévin Genna", year: 2021, position: "Postdoctoral fellow", institution: "Catolica Lisbon"},
  {name: "Hélène Le Forner", year: 2021, position: "Assistant Professor", institution: "Université Rennes 1"},
  {name: "Armel Ngami", year: 2021, position: "Statistician", institution: "Syneos Health"},
  {name: "Charles O'Donnell", year: 2021, position: "Economist", institution: "European Central Bank"},
  {name: "Océane Pietri", year: 2021, position: "Postdoctoral fellow", institution: "University Konstanz"},
  {name: "Eric Roca Fernandez", year: 2021, position: "Assistant professor", institution: "CERDI"},
  // 2020
  {name: "Rémi Vivès", year: 2020, position: "Assistant professor", institution: "York University"},
  {name: "Anwesha Banerjee", year: 2020, position: "Postdoctoral fellow", institution: "Munich Max Planck Institute"},
  {name: "Aissata Boubacar Moumouni", year: 2020, position: "Consultant Economist", institution: "International Trade Centre (UN)"},
  {name: "Laurène Bocognano", year: 2020, position: "Statistical analyst", institution: "French Ministry of Education"},
  {name: "Ulises Genis Cuevas", year: 2020, position: "Professor", institution: "Colegio de Tamaulipas"},
  {name: "Samuel Kembou Nzale", year: 2020, position: "Premier assistant", institution: "Université de Lausanne"},
  {name: "Tanguy Le Fur", year: 2020, position: "Postdoctoral fellow", institution: "NYU Abu Dhabi"},
  {name: "Jordan Loper", year: 2020, position: "Postdoctoral fellow", institution: "ENS Lyon"},
  {name: "Solène Masson", year: 2020, position: "Consultant economist", institution: "AFD"},
  {name: "Alberto Prati", year: 2020, position: "Postdoctoral fellow", institution: "Oxford"},
  {name: "Morgan Raux", year: 2020, position: "Postdoctoral fellow", institution: "University of Luxembourg"},
  {name: "Etienne Vaccaro-Grange", year: 2020, position: "Postdoctoral fellow", institution: "NYU Abu Dhabi"},
  {name: "Mathilde Valero", year: 2020, position: "Economist", institution: "DARES"},
  {name: "Raghul Venkatesh", year: 2020, position: "Postdoctoral fellow", institution: "University of Malaga"},
  // 2019
  {name: "Guillaume Wilemme", year: 2019, position: "Lecturer", institution: "Leicester University"},
  {name: "Marie-Christine Apedo-Amah", year: 2019, position: "Economist", institution: "World Bank"},
  {name: "Laila Ait Bihi Ouali", year: 2019, position: "Research Associate", institution: "Imperial College London"},
  {name: "Ugo Bolletta", year: 2019, position: "Postdoctoral Fellow", institution: "University of Antwerpen"},
  {name: "Victor Champonnois", year: 2019, position: "Postdoctoral fellow", institution: "IRSTEA"},
  {name: "Vera Danilina", year: 2019, position: "Teaching position", institution: "ESSCA Aix"},
  {name: "Nicolas Destrée", year: 2019, position: "Postdoctoral fellow", institution: "Univ. Nanterre"},
  {name: "Yezid Hernandez Luna", year: 2019, position: "Associate Professor", institution: "Jorge Tadeo Lozano University"},
  {name: "Pauline Morault", year: 2019, position: "Assistant Professor", institution: "University of Cergy"},
  {name: "Lara Vivian", year: 2019, position: "Economist", institution: "European Central Bank"},
  // 2018
  {name: "Clémentine Sadania", year: 2018, position: "Research Manager", institution: "Center for Evaluation and Development"},
  {name: "Majda Benzidia", year: 2018, position: "Statistician", institution: "OECD"},
  {name: "Cyril Dell'Eva", year: 2018, position: "Postdoctoral fellow", institution: "University of Pretoria"},
  {name: "Florent Dubois", year: 2018, position: "Postdoctoral fellow", institution: "University Paris X-Nanterre"},
  {name: "Guillaume Khayat", year: 2018, position: "Economist", institution: "Moody's Analytics"},
  {name: "Vivien Lespagnol", year: 2018, position: "Postdoctoral fellow", institution: "University of Nice"},
  {name: "Khalid Maman Waziri", year: 2018, position: "Research fellow", institution: "Overseas Development Institute"},
  {name: "François Reynaud", year: 2018, position: "Post-Doctoral fellow", institution: "DREES"},
  // 2017
  {name: "Antoine Bonleu", year: 2017, position: "Economist", institution: "Cereq"},
  {name: "Kadija Charni", year: 2017, position: "Post-doctoral fellow", institution: "Centre d'études de l'emploi"},
  {name: "Thomas Chuffart", year: 2017, position: "Assistant professor", institution: "Université de Franche-Comté"},
  {name: "Maxime Gueuder", year: 2017, position: "Economist", institution: "Banque de France"},
  {name: "Emma Hooper", year: 2017, position: "Economist", institution: "Direction Générale du Trésor"},
  {name: "Audrey Michel Lepage", year: 2017, position: "Consultant", institution: "Key Performance"},
  {name: "Justine Pedrono", year: 2017, position: "Economist", institution: "CEPII"},
  {name: "João Varandas Ferreira", year: 2017, position: "Post-doctoral fellow", institution: "Université de Rennes 1"},
  {name: "Anne-Charlotte Paret", year: 2017, position: "Economist", institution: "International Monetary Fund"}
];

async function updateCareers() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  console.log('Connected to database\n');

  const programId = '2b67e124-1368-48fe-9666-e8dbff007fa5'; // AMSE Economics

  let added = 0;
  let skipped = 0;

  for (const p of placements) {
    // Find faculty by name (case insensitive) and program
    const faculty = await client.query(`
      SELECT f.id, f.name FROM pt_faculty f
      JOIN pt_faculty_education e ON f.id = e.faculty_id
      WHERE LOWER(f.name) = LOWER($1)
        AND e.program_id = $2
        AND ABS(e.year - $3) <= 2
    `, [p.name, programId, p.year]);

    if (faculty.rows.length === 0) {
      continue; // Not found in our records
    }

    const facultyId = faculty.rows[0].id;

    // Check if career already exists
    const existing = await client.query(`
      SELECT id FROM pt_faculty_career
      WHERE faculty_id = $1 AND year = $2
    `, [facultyId, p.year]);

    if (existing.rows.length > 0) {
      skipped++;
      continue;
    }

    // Insert career record
    await client.query(`
      INSERT INTO pt_faculty_career (faculty_id, designation, institution_name, year, updated_at)
      VALUES ($1, $2, $3, $4, NOW())
    `, [facultyId, p.position, p.institution, p.year]);
    added++;
  }

  console.log(`Added: ${added} career records`);
  console.log(`Skipped: ${skipped} (already existed)`);

  await client.end();
}

updateCareers();
