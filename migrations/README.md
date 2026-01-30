# Database Migrations

This folder contains incremental database migrations for PandaInUniv Forum Plus.

## Structure

- `schema.sql` (root) - Complete schema for fresh database creation
- `migrations/` - Incremental changes for existing databases

## File Naming Convention

```
YYYYMMDD_NNN_description.sql
```

Examples:
- `20250130_001_add_avatar_path_column.sql`
- `20250130_002_create_notifications_table.sql`
- `20250201_001_add_poll_feature.sql`

## Migration Template

Each migration file should follow this structure:

```sql
-- Migration: YYYYMMDD_NNN_description
-- Description: Brief description of what this migration does
-- Author: Your name
-- Date: YYYY-MM-DD

-- =============================================================================
-- UP MIGRATION
-- =============================================================================

-- Your migration SQL here
ALTER TABLE example ADD COLUMN new_column TEXT;

-- Record this migration
INSERT INTO schema_version (version, description)
VALUES ('1.0.1', 'Add new_column to example table');

-- =============================================================================
-- DOWN MIGRATION (for rollback - keep commented)
-- =============================================================================
-- ALTER TABLE example DROP COLUMN new_column;
-- DELETE FROM schema_version WHERE version = '1.0.1';
```

## Running Migrations

### Check Current Version
```sql
SELECT * FROM schema_version ORDER BY applied_at DESC LIMIT 5;
```

### Apply a Migration
```bash
PGPASSWORD=your_password psql -h your_host -U your_user -d your_db -f migrations/20250130_001_description.sql
```

### Rollback (manual)
Uncomment and run the DOWN MIGRATION section from the migration file.

## Best Practices

1. **Idempotent**: Use `IF NOT EXISTS`, `IF EXISTS`, `ON CONFLICT DO NOTHING`
2. **Atomic**: Each migration should be a single logical change
3. **Tested**: Test on a copy of production data first
4. **Reversible**: Always include a DOWN migration (even if commented)
5. **Sequential**: Never modify a migration after it's been applied to production

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2025-01-30 | Initial versioned schema |
