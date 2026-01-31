# Placement Data Parsing Workflow

## Overview
Process placement URLs to extract graduate data and insert into pt_faculty, pt_faculty_education, and pt_faculty_career tables.

---

## Phase 1: URL Analysis (Before Parsing)

### Step 1.1: Check if URL is shared across multiple programs
```sql
SELECT unnest(placement_url) as url,
       array_agg(program_name || ' (' || degree || ')') as programs,
       count(*) as program_count
FROM pt_academic_programs
WHERE placement_url IS NOT NULL
GROUP BY unnest(placement_url)
HAVING count(*) > 1
```

### Step 1.2: For shared URLs - Fetch and check for program differentiation
```bash
python3 fetch-url.py "<URL>"
```

**Check the content for:**
- Section headers like "ACCOUNTING:", "FINANCE:", "MARKETING:" (e.g., MIT Sloan)
- Program-specific groupings
- Department labels

### Step 1.3: Determine URL ownership

**If page HAS program sections:**
- Parse each section separately
- Assign graduates to correct program based on section

**If page has NO program differentiation:**
- URL belongs to ONE program only
- Identify correct program from:
  - Page title (e.g., "PhD placement | AMSE | Aix-Marseille School of **Economics**")
  - Breadcrumbs
  - School/department name
- Other programs have INCORRECT URL mappings → remove URL from them

### Step 1.4: Verify with web search (5 random samples)
```
Search: "<Graduate Name> <University> PhD <field>"
```
Confirm which program graduates actually belong to.

---

## Phase 2: Fix Incorrect URL Mappings

If a URL belongs to only ONE program:

```sql
-- Remove URL from incorrect programs
UPDATE pt_academic_programs
SET placement_url = array_remove(placement_url, '<URL>')
WHERE id IN ('<wrong_program_id_1>', '<wrong_program_id_2>');
```

---

## Phase 2.5: Create Missing Programs

**IMPORTANT:** If a program exists on the page but NOT in the database, create it first. Never skip data.

### Step 2.5.1: Check if program exists
```sql
SELECT id, program_name FROM pt_academic_programs
WHERE LOWER(program_name) LIKE '%<program_name>%'
```

### Step 2.5.2: If program doesn't exist, create it
```sql
-- Get department_id from an existing program at same university
SELECT department_id FROM pt_academic_programs WHERE id = '<existing_program_id>';

-- Create new program
INSERT INTO pt_academic_programs (id, program_name, degree, department_id, placement_url, updated_at)
VALUES (gen_random_uuid(), '<program_name>', 'phd', '<department_id>', ARRAY['<url>'], NOW())
RETURNING id, program_name;
```

### Step 2.5.3: If program exists but missing URL, add it
```sql
UPDATE pt_academic_programs
SET placement_url = array_append(COALESCE(placement_url, ARRAY[]::text[]), '<url>')
WHERE id = '<program_id>';
```

---

## Phase 3: Data Extraction

### Step 3.1: Fetch raw content
```bash
python3 fetch-url.py "<URL>"
# Output saved to raw-content.txt
# Script automatically clicks "Expand all" buttons to get complete data
```

### Step 3.2: Manually create JSON
Review raw-content.txt and create structured JSON:

```json
{
  "source": {
    "url": "https://...",
    "program_name": "Economics",
    "degree": "PhD",
    "institution": "University Name",
    "institution_id": "uuid",
    "program_id": "uuid"
  },
  "extraction_date": "YYYY-MM-DD",
  "graduates": [
    {
      "name": "Full Name",
      "graduation_year": 2024,
      "placement": {
        "position": "Assistant Professor",
        "institution": "Hiring University"
      },
      "advisor": "Advisor Name"
    }
  ]
}
```

**Minimum required:** name + graduation_year
**Optional:** placement, advisor, thesis title

---

## Phase 4: Data Insertion

### Step 4.1: Run insertion script
```bash
node insert-placement-data.js placement-data-<school>-<program>.json
```

### Step 4.2: Duplicate detection logic
- Same name (case-insensitive) + same program_id + same institution_id + year within ±2 = duplicate → skip
- Same name but year differs by >2 = different person → insert

### Step 4.3: What gets inserted
1. **pt_faculty**: name, designation (from placement position)
2. **pt_faculty_education**: faculty_id, degree, field, institution_id, year, program_id, advisor
3. **pt_faculty_career**: faculty_id, designation, institution_name, year (only if placement available)
4. **pt_academic_programs**: Update last_parsed_at timestamp

---

## Phase 5: Cleanup (if needed)

### If duplicates were created across programs:

```sql
-- 1. Find records only in wrong program
SELECT e.id, f.name FROM pt_faculty_education e
JOIN pt_faculty f ON e.faculty_id = f.id
WHERE e.program_id = '<wrong_program_id>'
AND e.faculty_id NOT IN (
  SELECT faculty_id FROM pt_faculty_education WHERE program_id = '<correct_program_id>'
);

-- 2. Move unique records to correct program
UPDATE pt_faculty_education
SET program_id = '<correct_program_id>'
WHERE id IN (<ids_to_move>);

-- 3. Delete remaining duplicates
DELETE FROM pt_faculty_education WHERE program_id = '<wrong_program_id>';

-- 4. Remove URL from wrong programs
UPDATE pt_academic_programs
SET placement_url = array_remove(placement_url, '<URL>')
WHERE id = '<wrong_program_id>';
```

---

## Quick Reference: File Locations

| File | Purpose |
|------|---------|
| `fetch-url.py` | Fetch URL content (auto-handles anti-bot + accordions) |
| `raw-content.txt` | Raw fetched content for review |
| `insert-placement-data.js` | Batch insert from JSON |
| `placement-data-*.json` | Structured graduate data |

### fetch-url.py modes:
```bash
python3 fetch-url.py "<URL>"              # auto (expand first, fallback to scrapling)
python3 fetch-url.py "<URL>" expand       # force expand mode (for accordions)
python3 fetch-url.py "<URL>" scrapling    # force scrapling (for anti-bot sites)
```

---

## Key Principles

1. **Never skip data** - If a program exists on the page but not in DB, create it first
2. **Verify with web search** - For shared URLs without sections, verify 5 random graduates
3. **Create all programs** - Each section on a page = separate program in DB
4. **Click "Expand all"** - The fetch script handles this automatically

---

## Example: Processing a New URL

```bash
# 1. Check if URL is shared
# (run SQL query above)

# 2. Fetch content
python3 fetch-url.py "https://example.edu/phd/placements"

# 3. Review raw-content.txt for:
#    - Program sections? → Parse by section
#    - No sections? → Verify correct program via web search

# 4. Create JSON file
# placement-data-example-economics.json

# 5. Insert data
node insert-placement-data.js placement-data-example-economics.json

# 6. Verify
# Check database for inserted records
```
