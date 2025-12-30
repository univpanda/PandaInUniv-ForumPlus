-- =============================================================================
-- RESET DATABASE - Run this BEFORE schema.sql to start fresh
-- =============================================================================
-- WARNING: This will DELETE ALL DATA. Only use in development or when
-- intentionally resetting the database.
--
-- Run this in Supabase SQL Editor first, then run schema.sql
-- =============================================================================

-- Drop all triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop all functions (in reverse dependency order)
DROP FUNCTION IF EXISTS toggle_bookmark(INTEGER);
DROP FUNCTION IF EXISTS get_user_bookmarks(UUID);
DROP FUNCTION IF EXISTS is_user_ignored(UUID);
DROP FUNCTION IF EXISTS get_ignored_users();
DROP FUNCTION IF EXISTS toggle_ignore_user(UUID);
DROP FUNCTION IF EXISTS mark_conversation_read(UUID, UUID);
DROP FUNCTION IF EXISTS get_unread_message_count(UUID);
DROP FUNCTION IF EXISTS get_conversation_messages(UUID, UUID, INTEGER, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS get_user_conversations(UUID);
DROP FUNCTION IF EXISTS vote_poll(INTEGER, INTEGER[]);
DROP FUNCTION IF EXISTS get_poll_data(INTEGER);
DROP FUNCTION IF EXISTS create_poll_thread(TEXT, TEXT, TEXT[], BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_flagged_posts(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS toggle_post_flagged(INTEGER);
DROP FUNCTION IF EXISTS vote_post(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS edit_post(INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS delete_post(INTEGER);
DROP FUNCTION IF EXISTS get_paginated_thread_posts(INTEGER, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS add_reply(INTEGER, TEXT, INTEGER, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_paginated_forum_threads(INTEGER[], INTEGER, INTEGER, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN);
DROP FUNCTION IF EXISTS create_thread(TEXT, INTEGER, TEXT, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_users_paginated(INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS get_users_with_stats();
DROP FUNCTION IF EXISTS get_public_user_stats(UUID);
DROP FUNCTION IF EXISTS get_my_profile_stats();
DROP FUNCTION IF EXISTS delete_own_account();
DROP FUNCTION IF EXISTS update_username(TEXT);
DROP FUNCTION IF EXISTS get_reserved_usernames();
DROP FUNCTION IF EXISTS create_user_profile(UUID, TEXT);
DROP FUNCTION IF EXISTS handle_new_user();

-- Drop all tables (in reverse dependency order to handle foreign keys)
DROP TABLE IF EXISTS ignored_users CASCADE;
DROP TABLE IF EXISTS feedback_messages CASCADE;
DROP TABLE IF EXISTS poll_votes CASCADE;
DROP TABLE IF EXISTS poll_options CASCADE;
DROP TABLE IF EXISTS polls CASCADE;
DROP TABLE IF EXISTS bookmarks CASCADE;
DROP TABLE IF EXISTS post_votes CASCADE;
DROP TABLE IF EXISTS forum_posts CASCADE;
DROP TABLE IF EXISTS forum_threads CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Clean up any test users from auth.users (optional - uncomment if needed)
-- DELETE FROM auth.users WHERE email LIKE '%test%' OR email LIKE '%_deleted_%';

-- Done! Now run schema.sql to recreate everything
SELECT 'Database reset complete. Now run schema.sql to recreate tables.' as status;
