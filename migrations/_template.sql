-- Migration: YYYYMMDD_NNN_description
-- Description: [Brief description of what this migration does]
-- Author: [Your name]
-- Date: [YYYY-MM-DD]

-- =============================================================================
-- PRE-FLIGHT CHECK
-- =============================================================================
-- Verify we're at the expected version before applying
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM schema_version WHERE version = 'PREVIOUS_VERSION') THEN
    RAISE EXCEPTION 'Migration requires schema version PREVIOUS_VERSION';
  END IF;
END $$;

-- =============================================================================
-- UP MIGRATION
-- =============================================================================

-- [Your migration SQL here]
-- Example:
-- ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS new_column TEXT;

-- CREATE INDEX IF NOT EXISTS idx_new_column ON user_profiles(new_column);

-- =============================================================================
-- RECORD MIGRATION
-- =============================================================================
INSERT INTO schema_version (version, description)
VALUES ('NEW_VERSION', 'Description of this migration')
ON CONFLICT (version) DO NOTHING;

-- =============================================================================
-- DOWN MIGRATION (for rollback - keep commented until needed)
-- =============================================================================
/*
-- Rollback SQL:
-- ALTER TABLE user_profiles DROP COLUMN IF EXISTS new_column;
-- DROP INDEX IF EXISTS idx_new_column;

-- Remove version record:
-- DELETE FROM schema_version WHERE version = 'NEW_VERSION';
*/
