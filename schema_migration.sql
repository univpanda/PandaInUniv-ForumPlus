-- =============================================================================
-- PANDA FORUM - Schema Migration
-- =============================================================================
-- Applies incremental updates for denormalized counters and indexes.
-- Safe to run on an existing database (idempotent where possible).
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add denormalized counters (if missing)
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS likes INTEGER DEFAULT 0;
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS dislikes INTEGER DEFAULT 0;
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS reply_count INTEGER DEFAULT 0;

-- Add search documents for text search
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS search_document TSVECTOR;
ALTER TABLE forum_threads ADD COLUMN IF NOT EXISTS search_document TSVECTOR;

-- Indexes (skip if already present)
CREATE INDEX IF NOT EXISTS idx_forum_threads_title_trgm ON forum_threads USING GIN (LOWER(title) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_posts_content_trgm ON forum_posts USING GIN (LOWER(content) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_threads_search_document ON forum_threads USING GIN (search_document);
CREATE INDEX IF NOT EXISTS idx_forum_posts_search_document ON forum_posts USING GIN (search_document);
CREATE INDEX IF NOT EXISTS idx_forum_threads_category_last_activity ON forum_threads(category_id, last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_forum_threads_author_created ON forum_threads(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_parent_created ON forum_posts(thread_id, parent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_op ON forum_posts(thread_id) WHERE parent_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_post_votes_post_type ON post_votes(post_id, vote_type);
CREATE INDEX IF NOT EXISTS idx_post_votes_user_post ON post_votes(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_created ON bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_unread ON feedback_messages(recipient_id, user_id, created_at DESC) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_feedback_messages_recipient_unread ON feedback_messages(recipient_id) WHERE is_read = FALSE;

-- RLS policy adjustments
DROP POLICY IF EXISTS "Anyone can view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (
    auth.uid() = id
    OR EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND up.role = 'admin')
  );
REVOKE UPDATE ON user_profiles FROM anon, authenticated;

DROP POLICY IF EXISTS "Anyone can view posts" ON forum_posts;
DROP POLICY IF EXISTS "Anyone can view non-deleted posts" ON forum_posts;
DROP POLICY IF EXISTS "Non-blocked authors can update own posts" ON forum_posts;
CREATE POLICY "Anyone can view non-deleted posts" ON forum_posts
  FOR SELECT USING (
    COALESCE(is_deleted, FALSE) = FALSE
    OR EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND up.role = 'admin')
  );
REVOKE UPDATE ON forum_posts FROM anon, authenticated;

DROP POLICY IF EXISTS "Anyone can view votes" ON post_votes;
DROP POLICY IF EXISTS "Admins can view votes" ON post_votes;
CREATE POLICY "Admins can view votes" ON post_votes
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND up.role = 'admin')
  );

-- Backfill vote counts
UPDATE forum_posts p
SET likes = v.likes,
    dislikes = v.dislikes
FROM (
  SELECT post_id,
         COUNT(*) FILTER (WHERE vote_type = 1) AS likes,
         COUNT(*) FILTER (WHERE vote_type = -1) AS dislikes
  FROM post_votes
  GROUP BY post_id
) v
WHERE p.id = v.post_id;

-- Backfill reply counts (total replies)
UPDATE forum_posts p
SET reply_count = r.count
FROM (
  SELECT parent_id, COUNT(*) AS count
  FROM forum_posts
  WHERE parent_id IS NOT NULL
    AND COALESCE(is_deleted, FALSE) = FALSE
  GROUP BY parent_id
) r
WHERE p.id = r.parent_id;

-- Backfill search documents
UPDATE forum_posts
SET search_document = to_tsvector('simple', COALESCE(content, '') || ' ' || COALESCE(additional_comments, ''));

UPDATE forum_threads t
SET search_document = to_tsvector('simple', COALESCE(t.title, '') || ' ' || COALESCE(op.content, ''))
FROM forum_posts op
WHERE op.thread_id = t.id
  AND op.parent_id IS NULL;

UPDATE forum_threads t
SET search_document = to_tsvector('simple', COALESCE(t.title, ''))
WHERE t.search_document IS NULL;

-- Trigger to maintain reply_count on parent posts
CREATE OR REPLACE FUNCTION update_post_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.parent_id IS NOT NULL AND COALESCE(NEW.is_deleted, FALSE) = FALSE THEN
      UPDATE forum_posts
      SET reply_count = reply_count + 1
      WHERE id = NEW.parent_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.parent_id IS NOT NULL AND COALESCE(OLD.is_deleted, FALSE) = FALSE THEN
      UPDATE forum_posts
      SET reply_count = GREATEST(reply_count - 1, 0)
      WHERE id = OLD.parent_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_reply_count_insert ON forum_posts;
CREATE TRIGGER trigger_update_post_reply_count_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reply_count();

DROP TRIGGER IF EXISTS trigger_update_post_reply_count_delete ON forum_posts;
CREATE TRIGGER trigger_update_post_reply_count_delete
  AFTER DELETE ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reply_count();

-- Trigger to maintain reply_count on soft delete/restore
CREATE OR REPLACE FUNCTION update_post_reply_count_on_visibility()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF COALESCE(OLD.is_deleted, FALSE) = COALESCE(NEW.is_deleted, FALSE) THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_deleted, FALSE) = TRUE THEN
    UPDATE forum_posts
    SET reply_count = GREATEST(reply_count - 1, 0)
    WHERE id = NEW.parent_id;
  ELSE
    UPDATE forum_posts
    SET reply_count = reply_count + 1
    WHERE id = NEW.parent_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_reply_count_visibility ON forum_posts;
CREATE TRIGGER trigger_update_post_reply_count_visibility
  AFTER UPDATE OF is_deleted ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reply_count_on_visibility();

-- Trigger to maintain post search_document
CREATE OR REPLACE FUNCTION update_post_search_document()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_document := to_tsvector(
    'simple',
    COALESCE(NEW.content, '') || ' ' || COALESCE(NEW.additional_comments, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_search_document ON forum_posts;
CREATE TRIGGER trigger_update_post_search_document
  BEFORE INSERT OR UPDATE OF content, additional_comments ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_search_document();

-- Refresh thread search_document (title + OP content)
CREATE OR REPLACE FUNCTION refresh_thread_search_document(p_thread_id INTEGER)
RETURNS VOID AS $$
DECLARE
  v_title TEXT;
  v_op_content TEXT;
BEGIN
  SELECT t.title, op.content
  INTO v_title, v_op_content
  FROM forum_threads t
  LEFT JOIN forum_posts op
    ON op.thread_id = t.id AND op.parent_id IS NULL
  WHERE t.id = p_thread_id;

  UPDATE forum_threads
  SET search_document = to_tsvector(
    'simple',
    COALESCE(v_title, '') || ' ' || COALESCE(v_op_content, '')
  )
  WHERE id = p_thread_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_thread_search_document_from_thread()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM refresh_thread_search_document(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_thread_search_document_from_post()
RETURNS TRIGGER AS $$
DECLARE
  v_thread_id INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_thread_id := OLD.thread_id;
  ELSE
    v_thread_id := NEW.thread_id;
  END IF;

  PERFORM refresh_thread_search_document(v_thread_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_refresh_thread_search_document ON forum_threads;
CREATE TRIGGER trigger_refresh_thread_search_document
  AFTER INSERT OR UPDATE OF title ON forum_threads
  FOR EACH ROW
  EXECUTE FUNCTION refresh_thread_search_document_from_thread();

DROP TRIGGER IF EXISTS trigger_refresh_thread_search_document_op_insert ON forum_posts;
CREATE TRIGGER trigger_refresh_thread_search_document_op_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  WHEN (NEW.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

DROP TRIGGER IF EXISTS trigger_refresh_thread_search_document_op_update ON forum_posts;
CREATE TRIGGER trigger_refresh_thread_search_document_op_update
  AFTER UPDATE OF content, additional_comments ON forum_posts
  FOR EACH ROW
  WHEN (NEW.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

DROP TRIGGER IF EXISTS trigger_refresh_thread_search_document_op_delete ON forum_posts;
CREATE TRIGGER trigger_refresh_thread_search_document_op_delete
  AFTER DELETE ON forum_posts
  FOR EACH ROW
  WHEN (OLD.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

-- Trigger to maintain likes/dislikes counters on forum_posts
CREATE OR REPLACE FUNCTION update_post_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 1 THEN
      UPDATE forum_posts SET likes = likes + 1 WHERE id = NEW.post_id;
    ELSE
      UPDATE forum_posts SET dislikes = dislikes + 1 WHERE id = NEW.post_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.vote_type = NEW.vote_type THEN
      RETURN NEW;
    END IF;

    IF OLD.vote_type = 1 THEN
      UPDATE forum_posts SET likes = GREATEST(likes - 1, 0) WHERE id = NEW.post_id;
    ELSE
      UPDATE forum_posts SET dislikes = GREATEST(dislikes - 1, 0) WHERE id = NEW.post_id;
    END IF;

    IF NEW.vote_type = 1 THEN
      UPDATE forum_posts SET likes = likes + 1 WHERE id = NEW.post_id;
    ELSE
      UPDATE forum_posts SET dislikes = dislikes + 1 WHERE id = NEW.post_id;
    END IF;

    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vote_type = 1 THEN
      UPDATE forum_posts SET likes = GREATEST(likes - 1, 0) WHERE id = OLD.post_id;
    ELSE
      UPDATE forum_posts SET dislikes = GREATEST(dislikes - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_vote_counts_insert ON post_votes;
CREATE TRIGGER trigger_update_post_vote_counts_insert
  AFTER INSERT ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

DROP TRIGGER IF EXISTS trigger_update_post_vote_counts_update ON post_votes;
CREATE TRIGGER trigger_update_post_vote_counts_update
  AFTER UPDATE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

DROP TRIGGER IF EXISTS trigger_update_post_vote_counts_delete ON post_votes;
CREATE TRIGGER trigger_update_post_vote_counts_delete
  AFTER DELETE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

-- =============================================================================
-- Updated RPCs and security-sensitive functions
-- =============================================================================

DROP FUNCTION IF EXISTS get_public_user_profile(UUID);
DROP FUNCTION IF EXISTS get_my_profile_status();
DROP FUNCTION IF EXISTS update_login_metadata(TIMESTAMPTZ, INET, TEXT);
DROP FUNCTION IF EXISTS get_user_post_votes(INTEGER[]);
DROP FUNCTION IF EXISTS get_user_post_bookmarks(INTEGER[]);
DROP FUNCTION IF EXISTS is_username_available(TEXT);
DROP FUNCTION IF EXISTS set_user_role(UUID, TEXT);
DROP FUNCTION IF EXISTS set_user_blocked(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS create_thread(TEXT, INTEGER, TEXT, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS add_reply(INTEGER, TEXT, INTEGER, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS delete_post(INTEGER);
DROP FUNCTION IF EXISTS edit_post(INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS vote_post(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS toggle_post_flagged(INTEGER);
DROP FUNCTION IF EXISTS vote_poll(INTEGER, INTEGER[]);
DROP FUNCTION IF EXISTS toggle_ignore_user(UUID);
DROP FUNCTION IF EXISTS toggle_bookmark(INTEGER);
DROP FUNCTION IF EXISTS toggle_thread_bookmark(INTEGER);
DROP FUNCTION IF EXISTS toggle_post_bookmark(INTEGER);
DROP FUNCTION IF EXISTS get_paginated_forum_threads(INTEGER[], INTEGER, INTEGER, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN);
DROP FUNCTION IF EXISTS get_bookmarked_posts(UUID, INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS get_posts_by_author(TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS get_users_with_stats();
DROP FUNCTION IF EXISTS get_users_paginated(INTEGER, INTEGER, TEXT);

-- Public profile lookup (safe fields only)
CREATE OR REPLACE FUNCTION get_public_user_profile(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  username TEXT,
  avatar_url TEXT,
  avatar_path TEXT,
  is_private BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT up.id, up.username, up.avatar_url, up.avatar_path, up.is_private
  FROM user_profiles up
  WHERE up.id = p_user_id;
$$;

-- Get own profile status (role + blocked)
CREATE OR REPLACE FUNCTION get_my_profile_status()
RETURNS TABLE (
  role TEXT,
  is_blocked BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT up.role, COALESCE(up.is_blocked, FALSE)
  FROM user_profiles up
  WHERE up.id = auth.uid();
$$;

-- Get current user's vote for a list of posts
CREATE OR REPLACE FUNCTION get_user_post_votes(p_post_ids INTEGER[])
RETURNS TABLE (
  post_id INTEGER,
  vote_type INTEGER
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT pv.post_id, pv.vote_type
  FROM post_votes pv
  WHERE pv.user_id = auth.uid()
    AND pv.post_id = ANY(p_post_ids);
$$;

-- Get current user's bookmarks for a list of posts
CREATE OR REPLACE FUNCTION get_user_post_bookmarks(p_post_ids INTEGER[])
RETURNS TABLE (
  post_id INTEGER
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT b.post_id
  FROM bookmarks b
  WHERE b.user_id = auth.uid()
    AND b.post_id = ANY(p_post_ids);
$$;

-- Update own login metadata (last login/IP/location)
CREATE OR REPLACE FUNCTION update_login_metadata(
  p_last_login TIMESTAMPTZ DEFAULT NULL,
  p_last_ip INET DEFAULT NULL,
  p_last_location TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE user_profiles
  SET last_login = COALESCE(p_last_login, NOW()),
      last_ip = COALESCE(p_last_ip, last_ip),
      last_location = COALESCE(p_last_location, last_location)
  WHERE id = auth.uid();
END;
$$;

-- Check username availability (case-insensitive + reserved words)
CREATE OR REPLACE FUNCTION is_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_lower_username TEXT := LOWER(p_username);
  v_reserved_usernames TEXT[] := get_reserved_usernames();
BEGIN
  IF v_lower_username IS NULL OR v_lower_username = '' THEN
    RETURN FALSE;
  END IF;

  IF v_lower_username = ANY(v_reserved_usernames) THEN
    RETURN FALSE;
  END IF;

  IF v_lower_username LIKE '%moderator%' OR v_lower_username LIKE '%admin%' THEN
    RETURN FALSE;
  END IF;

  IF v_lower_username LIKE '%pandakeeper%' AND v_lower_username != 'pandakeeper' THEN
    RETURN FALSE;
  END IF;

  RETURN NOT EXISTS (
    SELECT 1 FROM user_profiles WHERE LOWER(username) = v_lower_username
  );
END;
$$;

-- Admin-only user role update
CREATE OR REPLACE FUNCTION set_user_role(p_user_id UUID, p_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_role NOT IN ('user', 'admin') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;

  UPDATE user_profiles SET role = p_role WHERE id = p_user_id;
  RETURN TRUE;
END;
$$;

-- Admin-only blocked status update
CREATE OR REPLACE FUNCTION set_user_blocked(p_user_id UUID, p_is_blocked BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE user_profiles SET is_blocked = p_is_blocked WHERE id = p_user_id;
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION get_public_user_profile(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_my_profile_status() TO authenticated;
GRANT EXECUTE ON FUNCTION update_login_metadata(TIMESTAMPTZ, INET, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_post_votes(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_post_bookmarks(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION is_username_available(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION set_user_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION set_user_blocked(UUID, BOOLEAN) TO authenticated;

-- Create thread with first post (blocked users denied)
CREATE OR REPLACE FUNCTION create_thread(
  p_title TEXT,
  p_category_id INTEGER,
  p_content TEXT,
  p_is_flagged BOOLEAN DEFAULT FALSE,
  p_flag_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_thread_id INTEGER;
  v_post_id INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  INSERT INTO forum_threads (title, category_id, author_id, is_flagged, flag_reason)
  VALUES (p_title, p_category_id, auth.uid(), p_is_flagged, p_flag_reason)
  RETURNING id INTO v_thread_id;

  INSERT INTO forum_posts (thread_id, author_id, content, is_flagged, flag_reason)
  VALUES (v_thread_id, auth.uid(), p_content, p_is_flagged, p_flag_reason)
  RETURNING id INTO v_post_id;

  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_thread_id;
END;
$$;

-- Add reply (blocked users denied)
CREATE OR REPLACE FUNCTION add_reply(
  p_thread_id INTEGER,
  p_content TEXT,
  p_parent_id INTEGER DEFAULT NULL,
  p_is_flagged BOOLEAN DEFAULT FALSE,
  p_flag_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post_id INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  INSERT INTO forum_posts (thread_id, parent_id, author_id, content, is_flagged, flag_reason)
  VALUES (p_thread_id, p_parent_id, auth.uid(), p_content, p_is_flagged, p_flag_reason)
  RETURNING id INTO v_post_id;

  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_post_id;
END;
$$;

-- Delete/undelete post (blocked users denied)
CREATE OR REPLACE FUNCTION delete_post(p_post_id INTEGER)
RETURNS TABLE (success BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post forum_posts%ROWTYPE;
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RETURN QUERY SELECT FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  SELECT * INTO v_post FROM forum_posts WHERE forum_posts.id = p_post_id;

  IF v_post IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Post not found'::TEXT;
    RETURN;
  END IF;

  SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE user_profiles.id = auth.uid();
  v_is_admin := COALESCE(v_is_admin, FALSE);

  IF v_post.author_id != auth.uid() AND NOT v_is_admin THEN
    RETURN QUERY SELECT FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  IF COALESCE(v_post.is_deleted, FALSE) THEN
    IF NOT v_is_admin THEN
      RETURN QUERY SELECT FALSE, 'Only admins can restore deleted posts'::TEXT;
      RETURN;
    END IF;
    UPDATE forum_posts SET is_deleted = FALSE, deleted_by = NULL WHERE forum_posts.id = p_post_id;
    RETURN QUERY SELECT TRUE, 'Post restored'::TEXT;
  ELSE
    UPDATE forum_posts SET is_deleted = TRUE, deleted_by = auth.uid() WHERE forum_posts.id = p_post_id;
    RETURN QUERY SELECT TRUE, 'Post deleted'::TEXT;
  END IF;
END;
$$;

-- Edit post (blocked users denied)
CREATE OR REPLACE FUNCTION edit_post(
  p_post_id INTEGER,
  p_content TEXT DEFAULT NULL,
  p_additional_comments TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, can_edit_content BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post forum_posts%ROWTYPE;
  v_can_edit_content BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  SELECT * INTO v_post FROM forum_posts WHERE forum_posts.id = p_post_id;

  IF v_post IS NULL THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Post not found'::TEXT;
    RETURN;
  END IF;

  IF v_post.author_id != auth.uid() THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  v_can_edit_content := (NOW() - v_post.created_at) < INTERVAL '15 minutes';

  IF p_content IS NOT NULL THEN
    IF NOT v_can_edit_content THEN
      RETURN QUERY SELECT FALSE, FALSE, 'Content edit window expired (15 minutes)'::TEXT;
      RETURN;
    END IF;
    UPDATE forum_posts SET content = p_content, edited_at = NOW() WHERE forum_posts.id = p_post_id;
  END IF;

  IF p_additional_comments IS NOT NULL THEN
    UPDATE forum_posts SET additional_comments =
      CASE
        WHEN additional_comments IS NULL OR additional_comments = ''
        THEN '[' || to_char(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ']' || p_additional_comments
        ELSE additional_comments || E'\n' || '[' || to_char(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ']' || p_additional_comments
      END
    WHERE forum_posts.id = p_post_id;
  END IF;

  RETURN QUERY SELECT TRUE, v_can_edit_content, 'Post updated'::TEXT;
END;
$$;

-- Vote on post (blocked users denied)
CREATE OR REPLACE FUNCTION vote_post(p_post_id INTEGER, p_vote_type INTEGER)
RETURNS TABLE (likes BIGINT, dislikes BIGINT, user_vote INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_vote INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT vote_type INTO v_existing_vote FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();

  IF p_vote_type = 0 THEN
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSIF v_existing_vote IS NULL THEN
    INSERT INTO post_votes (post_id, user_id, vote_type) VALUES (p_post_id, auth.uid(), p_vote_type);
  ELSIF v_existing_vote = p_vote_type THEN
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSE
    UPDATE post_votes SET vote_type = p_vote_type WHERE post_id = p_post_id AND user_id = auth.uid();
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(p.likes, 0),
    COALESCE(p.dislikes, 0),
    (SELECT pv.vote_type FROM post_votes pv WHERE pv.post_id = p_post_id AND pv.user_id = auth.uid())
  FROM forum_posts p
  WHERE p.id = p_post_id;
END;
$$;

-- Toggle post flagged status (admin only, blocked users denied)
CREATE OR REPLACE FUNCTION toggle_post_flagged(p_post_id INTEGER)
RETURNS TABLE (success BOOLEAN, is_flagged BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_current_flagged BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE user_profiles.id = auth.uid();

  IF NOT COALESCE(v_is_admin, FALSE) THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Admin access required'::TEXT;
    RETURN;
  END IF;

  SELECT forum_posts.is_flagged INTO v_current_flagged
  FROM forum_posts WHERE forum_posts.id = p_post_id;

  IF v_current_flagged IS NULL THEN
    RETURN QUERY SELECT FALSE, FALSE, 'Post not found'::TEXT;
    RETURN;
  END IF;

  UPDATE forum_posts SET is_flagged = NOT COALESCE(v_current_flagged, FALSE) WHERE forum_posts.id = p_post_id;

  RETURN QUERY SELECT TRUE, NOT COALESCE(v_current_flagged, FALSE),
    CASE WHEN v_current_flagged THEN 'Post unflagged' ELSE 'Post flagged' END::TEXT;
END;
$$;

-- Vote on poll (blocked users denied)
CREATE OR REPLACE FUNCTION vote_poll(p_poll_id INTEGER, p_option_ids INTEGER[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_poll polls%ROWTYPE;
  v_thread_id INTEGER;
  v_option_id INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT * INTO v_poll FROM polls WHERE id = p_poll_id;

  IF v_poll IS NULL THEN
    RAISE EXCEPTION 'Poll not found';
  END IF;

  IF v_poll.ends_at IS NOT NULL AND v_poll.ends_at < NOW() THEN
    RAISE EXCEPTION 'Poll has ended';
  END IF;

  IF NOT v_poll.allow_vote_change AND EXISTS (SELECT 1 FROM poll_votes WHERE poll_id = p_poll_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Vote change not allowed';
  END IF;

  IF NOT v_poll.allow_multiple AND array_length(p_option_ids, 1) > 1 THEN
    RAISE EXCEPTION 'Multiple votes not allowed';
  END IF;

  DELETE FROM poll_votes WHERE poll_id = p_poll_id AND user_id = auth.uid();

  FOREACH v_option_id IN ARRAY p_option_ids LOOP
    INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES (p_poll_id, v_option_id, auth.uid());
  END LOOP;

  SELECT thread_id INTO v_thread_id FROM polls WHERE id = p_poll_id;
  RETURN get_poll_data(v_thread_id);
END;
$$;

-- Toggle ignore user (blocked users denied)
CREATE OR REPLACE FUNCTION toggle_ignore_user(p_ignored_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT EXISTS(SELECT 1 FROM ignored_users WHERE user_id = auth.uid() AND ignored_user_id = p_ignored_user_id) INTO v_exists;

  IF v_exists THEN
    DELETE FROM ignored_users WHERE user_id = auth.uid() AND ignored_user_id = p_ignored_user_id;
    RETURN FALSE;
  ELSE
    INSERT INTO ignored_users (user_id, ignored_user_id) VALUES (auth.uid(), p_ignored_user_id);
    RETURN TRUE;
  END IF;
END;
$$;

-- Toggle bookmark (blocked users denied)
CREATE OR REPLACE FUNCTION toggle_bookmark(p_post_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT EXISTS(SELECT 1 FROM bookmarks WHERE user_id = auth.uid() AND post_id = p_post_id) INTO v_exists;

  IF v_exists THEN
    DELETE FROM bookmarks WHERE user_id = auth.uid() AND post_id = p_post_id;
    RETURN FALSE;
  ELSE
    INSERT INTO bookmarks (user_id, post_id) VALUES (auth.uid(), p_post_id);
    RETURN TRUE;
  END IF;
END;
$$;

-- Toggle thread bookmark (blocked users denied)
CREATE OR REPLACE FUNCTION toggle_thread_bookmark(p_thread_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_op_post_id INTEGER;
  v_exists BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT id INTO v_op_post_id
  FROM forum_posts
  WHERE thread_id = p_thread_id AND parent_id IS NULL
  LIMIT 1;

  IF v_op_post_id IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT EXISTS(SELECT 1 FROM bookmarks WHERE user_id = auth.uid() AND post_id = v_op_post_id) INTO v_exists;

  IF v_exists THEN
    DELETE FROM bookmarks WHERE user_id = auth.uid() AND post_id = v_op_post_id;
    RETURN FALSE;
  ELSE
    INSERT INTO bookmarks (user_id, post_id) VALUES (auth.uid(), v_op_post_id);
    RETURN TRUE;
  END IF;
END;
$$;

-- Toggle post bookmark (blocked users denied)
CREATE OR REPLACE FUNCTION toggle_post_bookmark(p_post_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT EXISTS(SELECT 1 FROM bookmarks WHERE user_id = auth.uid() AND post_id = p_post_id) INTO v_exists;

  IF v_exists THEN
    DELETE FROM bookmarks WHERE user_id = auth.uid() AND post_id = p_post_id;
    RETURN FALSE;
  ELSE
    INSERT INTO bookmarks (user_id, post_id) VALUES (auth.uid(), p_post_id);
    RETURN TRUE;
  END IF;
END;
$$;

-- Get paginated forum threads (search via tsvector)
CREATE OR REPLACE FUNCTION get_paginated_forum_threads(
  p_category_ids INTEGER[] DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort_by TEXT DEFAULT 'recent',
  p_author_username TEXT DEFAULT NULL,
  p_search_text TEXT DEFAULT NULL,
  p_flagged_only BOOLEAN DEFAULT FALSE,
  p_deleted_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  id INTEGER,
  title TEXT,
  author_id UUID,
  author_name TEXT,
  author_avatar TEXT,
  author_avatar_path TEXT,
  created_at TIMESTAMPTZ,
  first_post_content TEXT,
  reply_count BIGINT,
  total_likes BIGINT,
  total_dislikes BIGINT,
  is_op_deleted BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE user_profiles.id = auth.uid();
  v_is_admin := COALESCE(v_is_admin, FALSE);

  SELECT COUNT(*) INTO v_total
  FROM forum_threads t
  JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
  JOIN user_profiles u ON u.id = t.author_id
  WHERE (p_category_ids IS NULL OR t.category_id = ANY(p_category_ids))
    AND (p_author_username IS NULL OR LOWER(u.username) = LOWER(p_author_username))
    AND (p_search_text IS NULL OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
    AND (NOT p_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
    AND (NOT p_deleted_only OR op.is_deleted = TRUE)
    AND (v_is_admin OR COALESCE(op.is_deleted, FALSE) = FALSE
         OR EXISTS (SELECT 1 FROM forum_posts r WHERE r.thread_id = t.id AND r.parent_id IS NOT NULL AND COALESCE(r.is_deleted, FALSE) = FALSE));

  RETURN QUERY
  SELECT * FROM (
    SELECT
      t.id,
      t.title,
      t.author_id,
      u.username,
      u.avatar_url,
      u.avatar_path,
      CASE WHEN p_sort_by = 'recent' THEN COALESCE(t.last_activity, t.created_at) ELSE t.created_at END AS created_at,
      op.content,
      COALESCE(op.reply_count, 0) AS reply_count,
      COALESCE(op.likes, 0) AS total_likes,
      COALESCE(op.dislikes, 0) AS total_dislikes,
      COALESCE(op.is_deleted, FALSE) AS is_op_deleted,
      v_total AS total_count
    FROM forum_threads t
    JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
    JOIN user_profiles u ON u.id = t.author_id
    WHERE (p_category_ids IS NULL OR t.category_id = ANY(p_category_ids))
      AND (p_author_username IS NULL OR LOWER(u.username) = LOWER(p_author_username))
      AND (p_search_text IS NULL OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
      AND (NOT p_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
      AND (NOT p_deleted_only OR op.is_deleted = TRUE)
      AND (v_is_admin OR COALESCE(op.is_deleted, FALSE) = FALSE
           OR EXISTS (SELECT 1 FROM forum_posts r WHERE r.thread_id = t.id AND r.parent_id IS NOT NULL AND COALESCE(r.is_deleted, FALSE) = FALSE))
  ) sub
  ORDER BY
    CASE WHEN p_sort_by = 'recent' THEN sub.created_at END DESC,
    CASE WHEN p_sort_by = 'popular' THEN sub.total_likes END DESC,
    CASE WHEN p_sort_by = 'popular' THEN sub.reply_count END DESC,
    sub.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Get paginated bookmarked posts (search via tsvector)
CREATE OR REPLACE FUNCTION get_bookmarked_posts(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_search_text TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_posts JSON;
  v_total BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM bookmarks b
  JOIN forum_posts p ON p.id = b.post_id
  JOIN forum_threads t ON t.id = p.thread_id
  WHERE b.user_id = p_user_id
    AND COALESCE(p.is_deleted, FALSE) = FALSE
    AND (p_search_text IS NULL OR p.search_document @@ websearch_to_tsquery('simple', p_search_text)
         OR t.search_document @@ websearch_to_tsquery('simple', p_search_text));

  SELECT json_agg(row_to_json(posts_data)) INTO v_posts
  FROM (
    SELECT
      p.id,
      p.thread_id,
      t.title AS thread_title,
      p.parent_id,
      p.content,
      p.author_id,
      u.username AS author_name,
      u.avatar_url AS author_avatar,
      u.avatar_path AS author_avatar_path,
      p.created_at,
      p.edited_at,
      COALESCE(p.likes, 0) AS likes,
      COALESCE(p.dislikes, 0) AS dislikes,
      (SELECT pv.vote_type FROM post_votes pv WHERE pv.post_id = p.id AND pv.user_id = auth.uid()) AS user_vote,
      COALESCE(p.reply_count, 0) AS reply_count,
      p.is_flagged,
      p.flag_reason,
      COALESCE(p.is_deleted, FALSE) AS is_deleted,
      p.deleted_by,
      p.additional_comments,
      NULL::TEXT AS first_reply_content,
      NULL::TEXT AS first_reply_author,
      NULL::TEXT AS first_reply_avatar,
      NULL::TEXT AS first_reply_avatar_path,
      NULL::TIMESTAMPTZ AS first_reply_date
    FROM bookmarks b
    JOIN forum_posts p ON p.id = b.post_id
    JOIN forum_threads t ON t.id = p.thread_id
    JOIN user_profiles u ON u.id = p.author_id
    WHERE b.user_id = p_user_id
      AND COALESCE(p.is_deleted, FALSE) = FALSE
      AND (p_search_text IS NULL OR p.search_document @@ websearch_to_tsquery('simple', p_search_text)
           OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
    ORDER BY b.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) posts_data;

  RETURN json_build_object(
    'posts', COALESCE(v_posts, '[]'::JSON),
    'total_count', v_total
  );
END;
$$;

-- Author posts search (search via tsvector)
CREATE OR REPLACE FUNCTION get_posts_by_author(
  p_author_username TEXT DEFAULT NULL,
  p_search_text TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_flagged_only BOOLEAN DEFAULT FALSE,
  p_deleted_only BOOLEAN DEFAULT FALSE,
  p_post_type TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_posts JSON;
  v_total BIGINT;
  v_is_admin BOOLEAN;
  v_author_id UUID;
  v_author_is_private BOOLEAN;
  v_current_user_id UUID;
  v_current_username TEXT;
BEGIN
  v_current_user_id := auth.uid();

  SELECT role = 'admin', username INTO v_is_admin, v_current_username
  FROM user_profiles WHERE id = v_current_user_id;
  v_is_admin := COALESCE(v_is_admin, FALSE);

  IF p_author_username IS NOT NULL AND p_author_username != '' THEN
    SELECT id, COALESCE(is_private, FALSE) INTO v_author_id, v_author_is_private
    FROM user_profiles WHERE LOWER(username) = LOWER(p_author_username);

    IF v_author_id IS NULL THEN
      RETURN json_build_object('posts', '[]'::JSON, 'total_count', 0, 'is_private', FALSE);
    END IF;

    IF v_author_is_private AND NOT v_is_admin AND v_author_id != v_current_user_id THEN
      RETURN json_build_object('posts', '[]'::JSON, 'total_count', 0, 'is_private', TRUE);
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM forum_posts p
  JOIN forum_threads t ON t.id = p.thread_id
  WHERE (v_author_id IS NULL OR p.author_id = v_author_id)
    AND (p_search_text IS NULL OR p.search_document @@ websearch_to_tsquery('simple', p_search_text)
         OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
    AND (NOT p_flagged_only OR p.is_flagged = TRUE)
    AND (NOT p_deleted_only OR COALESCE(p.is_deleted, FALSE) = TRUE)
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
    AND (p_post_type IS NULL OR p_post_type = 'all'
         OR (p_post_type = 'op' AND p.parent_id IS NULL)
         OR (p_post_type = 'replies' AND p.parent_id IS NOT NULL));

  SELECT json_agg(row_to_json(posts_data)) INTO v_posts
  FROM (
    SELECT
      p.id,
      p.thread_id,
      t.title AS thread_title,
      p.parent_id,
      p.content,
      p.author_id,
      u.username AS author_name,
      u.avatar_url AS author_avatar,
      u.avatar_path AS author_avatar_path,
      p.created_at,
      COALESCE(p.likes, 0) AS likes,
      COALESCE(p.dislikes, 0) AS dislikes,
      COALESCE(p.reply_count, 0) AS reply_count,
      COALESCE(p.is_deleted, FALSE) AS is_deleted,
      p.deleted_by,
      p.is_flagged,
      (p.parent_id IS NULL) AS is_thread_op
    FROM forum_posts p
    JOIN forum_threads t ON t.id = p.thread_id
    JOIN user_profiles u ON u.id = p.author_id
    WHERE (v_author_id IS NULL OR p.author_id = v_author_id)
      AND (p_search_text IS NULL OR p.search_document @@ websearch_to_tsquery('simple', p_search_text)
           OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
      AND (NOT p_flagged_only OR p.is_flagged = TRUE)
      AND (NOT p_deleted_only OR COALESCE(p.is_deleted, FALSE) = TRUE)
      AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
      AND (p_post_type IS NULL OR p_post_type = 'all'
           OR (p_post_type = 'op' AND p.parent_id IS NULL)
           OR (p_post_type = 'replies' AND p.parent_id IS NOT NULL))
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) posts_data;

  RETURN json_build_object(
    'posts', COALESCE(v_posts, '[]'::JSON),
    'total_count', v_total,
    'is_private', FALSE
  );
END;
$$;

-- Admin: Get all users with stats (optimized)
CREATE OR REPLACE FUNCTION get_users_with_stats()
RETURNS TABLE (
  id UUID,
  username TEXT,
  email TEXT,
  avatar_url TEXT,
  role TEXT,
  is_blocked BOOLEAN,
  is_deleted BOOLEAN,
  created_at TIMESTAMPTZ,
  last_login TIMESTAMPTZ,
  thread_count BIGINT,
  post_count BIGINT,
  flagged_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  WITH thread_counts AS (
    SELECT author_id, COUNT(*) AS thread_count
    FROM forum_threads
    GROUP BY author_id
  ),
  post_counts AS (
    SELECT author_id,
           COUNT(*) FILTER (WHERE parent_id IS NOT NULL) AS post_count,
           COUNT(*) FILTER (WHERE is_flagged = TRUE) AS flagged_count
    FROM forum_posts
    GROUP BY author_id
  )
  SELECT
    up.id,
    up.username,
    au.email,
    up.avatar_url,
    up.role,
    COALESCE(up.is_blocked, FALSE),
    COALESCE(up.is_deleted, FALSE),
    up.created_at,
    up.last_login,
    COALESCE(tc.thread_count, 0),
    COALESCE(pc.post_count, 0),
    COALESCE(pc.flagged_count, 0)
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  LEFT JOIN thread_counts tc ON tc.author_id = up.id
  LEFT JOIN post_counts pc ON pc.author_id = up.id
  ORDER BY up.created_at DESC;
END;
$$;

-- Admin: Get paginated users with full stats (optimized)
CREATE OR REPLACE FUNCTION get_users_paginated(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  username TEXT,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  role TEXT,
  is_blocked BOOLEAN,
  is_deleted BOOLEAN,
  created_at TIMESTAMPTZ,
  last_login TIMESTAMPTZ,
  last_ip INET,
  last_location TEXT,
  thread_count BIGINT,
  post_count BIGINT,
  deleted_count BIGINT,
  flagged_count BIGINT,
  upvotes_received BIGINT,
  downvotes_received BIGINT,
  upvotes_given BIGINT,
  downvotes_given BIGINT,
  total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total BIGINT;
  v_search_pattern TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_search IS NOT NULL AND p_search != '' THEN
    IF LEFT(p_search, 1) = '@' THEN
      v_search_pattern := '%' || LOWER(SUBSTRING(p_search FROM 2)) || '%';
    ELSE
      v_search_pattern := '%' || LOWER(p_search) || '%';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  WHERE (v_search_pattern IS NULL
    OR LOWER(up.username) LIKE v_search_pattern
    OR LOWER(au.email::TEXT) LIKE v_search_pattern);

  RETURN QUERY
  WITH thread_counts AS (
    SELECT author_id, COUNT(*) AS thread_count
    FROM forum_threads
    GROUP BY author_id
  ),
  post_counts AS (
    SELECT author_id,
           COUNT(*) AS post_count,
           COUNT(*) FILTER (WHERE is_deleted = TRUE) AS deleted_count,
           COUNT(*) FILTER (WHERE is_flagged = TRUE) AS flagged_count
    FROM forum_posts
    GROUP BY author_id
  ),
  vote_received AS (
    SELECT fp.author_id,
           COUNT(*) FILTER (WHERE pv.vote_type = 1) AS upvotes_received,
           COUNT(*) FILTER (WHERE pv.vote_type = -1) AS downvotes_received
    FROM post_votes pv
    JOIN forum_posts fp ON pv.post_id = fp.id
    GROUP BY fp.author_id
  ),
  vote_given AS (
    SELECT user_id,
           COUNT(*) FILTER (WHERE vote_type = 1) AS upvotes_given,
           COUNT(*) FILTER (WHERE vote_type = -1) AS downvotes_given
    FROM post_votes
    GROUP BY user_id
  )
  SELECT
    up.id,
    up.username,
    au.email::TEXT,
    (au.raw_user_meta_data->>'full_name')::TEXT,
    up.avatar_url,
    up.role,
    COALESCE(up.is_blocked, FALSE),
    COALESCE(up.is_deleted, FALSE),
    up.created_at,
    up.last_login,
    up.last_ip,
    up.last_location,
    COALESCE(tc.thread_count, 0),
    COALESCE(pc.post_count, 0),
    COALESCE(pc.deleted_count, 0),
    COALESCE(pc.flagged_count, 0),
    COALESCE(vr.upvotes_received, 0),
    COALESCE(vr.downvotes_received, 0),
    COALESCE(vg.upvotes_given, 0),
    COALESCE(vg.downvotes_given, 0),
    v_total
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  LEFT JOIN thread_counts tc ON tc.author_id = up.id
  LEFT JOIN post_counts pc ON pc.author_id = up.id
  LEFT JOIN vote_received vr ON vr.author_id = up.id
  LEFT JOIN vote_given vg ON vg.user_id = up.id
  WHERE (v_search_pattern IS NULL
    OR LOWER(up.username) LIKE v_search_pattern
    OR LOWER(au.email::TEXT) LIKE v_search_pattern)
  ORDER BY up.last_login DESC NULLS LAST, up.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
