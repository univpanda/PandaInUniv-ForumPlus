-- =============================================================================
-- PANDA FORUM - Complete Database Schema
-- =============================================================================
-- This script creates all tables, indexes, RLS policies, and functions needed
-- to run the Panda Forum application with Supabase.
--
-- Prerequisites:
--   - Supabase project with auth.users table
--   - Run this script in Supabase SQL Editor
--
-- Features:
--   - User profiles with roles (user/admin)
--   - Forum threads and posts with nested replies
--   - Voting system (upvote/downvote)
--   - Post flagging and moderation
--   - Polls attached to threads
--   - User-to-user messaging
--   - Bookmarks
--   - User ignore list
-- =============================================================================


-- =============================================================================
-- 0. HELPER FUNCTIONS
-- =============================================================================

-- Text search acceleration
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Helper function to check if current user is blocked (used in RLS policies)
CREATE OR REPLACE FUNCTION public.is_not_blocked()
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.is_blocked = true
  );
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.is_not_blocked() TO authenticated;

-- Helper function to check if a user is admin (used in SECURITY DEFINER RPCs)
CREATE OR REPLACE FUNCTION public.check_is_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT COALESCE((SELECT role = 'admin' FROM public.user_profiles WHERE id = p_user_id), FALSE);
$$;


-- =============================================================================
-- 1. USER PROFILES
-- =============================================================================

CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  avatar_path TEXT, -- e.g., 'kawaii/chef' or 'cartoon/gamer'
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  is_blocked BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  is_private BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_login TIMESTAMPTZ,
  last_ip INET,
  last_location TEXT
);

CREATE TABLE IF NOT EXISTS user_stats (
  user_id UUID PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
  thread_count BIGINT DEFAULT 0,
  post_count BIGINT DEFAULT 0,
  deleted_count BIGINT DEFAULT 0,
  flagged_count BIGINT DEFAULT 0,
  upvotes_received BIGINT DEFAULT 0,
  downvotes_received BIGINT DEFAULT 0,
  upvotes_given BIGINT DEFAULT 0,
  downvotes_given BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_stats_updated ON user_stats(updated_at DESC);

-- Case-insensitive username uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS user_profiles_username_lower_idx
  ON user_profiles (LOWER(username));

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can view own profile; admins can view all
-- NOTE: Uses check_is_admin() function instead of EXISTS subquery to avoid infinite recursion
-- (the policy cannot reference user_profiles itself)
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (
    auth.uid() = user_profiles.id OR public.check_is_admin()
  );

-- Create user profile (called from app after successful auth)
-- This replaces the trigger approach which doesn't work with GoTrue
CREATE OR REPLACE FUNCTION generate_panda_username()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  -- Panda activity/behavior adjectives (60 words)
  v_adjectives TEXT[] := ARRAY[
    -- Eating behaviors
    'Munching', 'Chomping', 'Snacking', 'Nibbling', 'Crunching', 'Chewing',
    -- Sleeping behaviors
    'Sleepy', 'Napping', 'Dozing', 'Snoozing', 'Drowsy', 'Dreamy',
    -- Movement behaviors
    'Rolling', 'Tumbling', 'Climbing', 'Wobbling', 'Waddling', 'Stumbling',
    'Bumbling', 'Bouncing', 'Hopping', 'Crawling', 'Roaming', 'Wandering',
    -- Relaxing behaviors
    'Lazy', 'Lounging', 'Chilling', 'Relaxing', 'Resting', 'Yawning',
    -- Cute/personality behaviors
    'Cuddly', 'Fluffy', 'Playful', 'Curious', 'Bashful', 'Gentle',
    'Happy', 'Jolly', 'Cheerful', 'Giggly', 'Silly', 'Goofy',
    -- Physical traits
    'Chubby', 'Pudgy', 'Fuzzy', 'Plump', 'Roly', 'Squishy',
    -- Nature/habitat
    'Bamboo', 'Misty', 'Mountain', 'Forest', 'Wild', 'Hidden'
  ];
BEGIN
  -- Format: [Adjective]Panda[4-digit-number]
  -- 60 adjectives × 10000 numbers = 600,000 unique combinations
  RETURN v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::int]
      || 'Panda'
      || lpad(floor(random() * 10000)::text, 4, '0');
END;
$$;

-- Create user profile (called from app after successful auth)
-- Username and avatar_path are now generated by the frontend
CREATE OR REPLACE FUNCTION create_user_profile(
  p_user_id UUID,
  p_email TEXT,
  p_username TEXT DEFAULT NULL,
  p_avatar_path TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, username TEXT, message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_final_username TEXT;
  v_pandakeeper_id UUID;
  v_welcome_message TEXT;
BEGIN
  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = p_user_id) THEN
    SELECT up.username INTO v_final_username FROM user_profiles up WHERE up.id = p_user_id;
    RETURN QUERY SELECT TRUE, v_final_username, 'Profile already exists'::TEXT;
    RETURN;
  END IF;

  -- Use provided username or generate fallback
  v_final_username := COALESCE(p_username, 'Panda' || lpad(floor(random() * 10000)::text, 4, '0'));

  -- Check for username collision, append UUID fragment if needed
  IF EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = LOWER(v_final_username)) THEN
    v_final_username := v_final_username || substr(p_user_id::text, 1, 4);
  END IF;

  -- Insert the new user profile
  INSERT INTO user_profiles (id, username, role, avatar_path)
  VALUES (p_user_id, v_final_username, 'user', p_avatar_path);

  INSERT INTO user_stats (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Send welcome message from PandaKeeper
  SELECT up.id INTO v_pandakeeper_id FROM user_profiles up WHERE up.username = 'PandaKeeper' LIMIT 1;

  IF v_pandakeeper_id IS NOT NULL THEN
    v_welcome_message := 'Hello ' || v_final_username || '!

Welcome to PandaInUniv! I''m PandaKeeper, here to help you get started.

Here''s how things work:
• Grove - Where pandas discuss and share chomps (posts)
• Den - Private whispers with other pandas
• Profile - Your personal burrow

A few tips:
• Be kind to fellow pandas
• Chomp responsibly!

If you have questions or suggestions, just whisper back. Happy foraging!';

    INSERT INTO feedback_messages (user_id, recipient_id, content)
    VALUES (v_pandakeeper_id, p_user_id, v_welcome_message);
  END IF;

  RETURN QUERY SELECT TRUE, v_final_username, 'Profile created'::TEXT;
END;
$$;

-- RLS policy to allow authenticated users to insert their own profile
CREATE POLICY "Users can insert own profile" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Prevent direct profile updates; use RPCs instead
REVOKE UPDATE ON user_profiles FROM anon, authenticated;

-- Ensure stats row exists for every user profile
CREATE OR REPLACE FUNCTION ensure_user_stats()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_stats (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_ensure_user_stats ON user_profiles;
CREATE TRIGGER trigger_ensure_user_stats
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_stats();


-- =============================================================================
-- 2. FORUM THREADS
-- =============================================================================

CREATE TABLE IF NOT EXISTS forum_threads (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  category_id INTEGER,
  author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  is_flagged BOOLEAN DEFAULT FALSE,
  flag_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  search_document TSVECTOR
);

CREATE INDEX IF NOT EXISTS idx_forum_threads_author ON forum_threads(author_id);
CREATE INDEX IF NOT EXISTS idx_forum_threads_created ON forum_threads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_threads_last_activity ON forum_threads(last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_forum_threads_flagged ON forum_threads(is_flagged) WHERE is_flagged = TRUE;
CREATE INDEX IF NOT EXISTS idx_forum_threads_title_trgm ON forum_threads USING GIN (LOWER(title) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_threads_search_document ON forum_threads USING GIN (search_document);
CREATE INDEX IF NOT EXISTS idx_forum_threads_category_last_activity ON forum_threads(category_id, last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_forum_threads_author_created ON forum_threads(author_id, created_at DESC);

ALTER TABLE forum_threads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view threads" ON forum_threads
  FOR SELECT USING (true);

CREATE POLICY "Non-blocked users can create threads" ON forum_threads
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND public.is_not_blocked()
  );


-- =============================================================================
-- 3. FORUM POSTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS forum_posts (
  id SERIAL PRIMARY KEY,
  thread_id INTEGER NOT NULL REFERENCES forum_threads(id) ON DELETE CASCADE,
  parent_id INTEGER REFERENCES forum_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  additional_comments TEXT,
  is_flagged BOOLEAN DEFAULT FALSE,
  flag_reason TEXT,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  edited_at TIMESTAMPTZ,
  search_document TSVECTOR,
  likes BIGINT DEFAULT 0,
  dislikes BIGINT DEFAULT 0,
  reply_count BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_forum_posts_thread ON forum_posts(thread_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_parent ON forum_posts(parent_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_author ON forum_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_flagged ON forum_posts(is_flagged) WHERE is_flagged = TRUE;

-- Composite indexes for faster search queries
CREATE INDEX IF NOT EXISTS idx_forum_posts_author_created ON forum_posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_parent ON forum_posts(thread_id, parent_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_created ON forum_posts(thread_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_parent_created ON forum_posts(thread_id, parent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_op ON forum_posts(thread_id) WHERE parent_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_forum_posts_content_trgm ON forum_posts USING GIN (LOWER(content) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_posts_search_document ON forum_posts USING GIN (search_document);

ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view non-deleted posts" ON forum_posts
  FOR SELECT USING (
    COALESCE(is_deleted, FALSE) = FALSE
    OR EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND up.role = 'admin')
  );

CREATE POLICY "Non-blocked users can create posts" ON forum_posts
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND public.is_not_blocked()
  );

-- Prevent direct post updates; use RPCs instead
REVOKE UPDATE ON forum_posts FROM anon, authenticated;


-- Trigger to update thread last_activity when a post is created
CREATE OR REPLACE FUNCTION update_thread_last_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE forum_threads
  SET last_activity = NEW.created_at
  WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_thread_last_activity
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_thread_last_activity();

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
    ON op.thread_id = t.id AND op.parent_id IS NULL AND COALESCE(op.is_deleted, FALSE) = FALSE
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

CREATE TRIGGER trigger_refresh_thread_search_document
  AFTER INSERT OR UPDATE OF title ON forum_threads
  FOR EACH ROW
  EXECUTE FUNCTION refresh_thread_search_document_from_thread();

CREATE TRIGGER trigger_refresh_thread_search_document_op_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  WHEN (NEW.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

CREATE TRIGGER trigger_refresh_thread_search_document_op_update
  AFTER UPDATE OF content, additional_comments ON forum_posts
  FOR EACH ROW
  WHEN (NEW.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

CREATE TRIGGER trigger_refresh_thread_search_document_op_delete
  AFTER DELETE ON forum_posts
  FOR EACH ROW
  WHEN (OLD.parent_id IS NULL)
  EXECUTE FUNCTION refresh_thread_search_document_from_post();

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

CREATE TRIGGER trigger_update_post_reply_count_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reply_count();

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

CREATE TRIGGER trigger_update_post_reply_count_visibility
  AFTER UPDATE OF is_deleted ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reply_count_on_visibility();


-- =============================================================================
-- 4. POST VOTES
-- =============================================================================

CREATE TABLE IF NOT EXISTS post_votes (
  id SERIAL PRIMARY KEY,
  post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  vote_type INTEGER NOT NULL CHECK (vote_type IN (1, -1)),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_votes_post ON post_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_votes_user ON post_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_votes_post_type ON post_votes(post_id, vote_type);
CREATE INDEX IF NOT EXISTS idx_post_votes_user_post ON post_votes(user_id, post_id);

ALTER TABLE post_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view votes" ON post_votes
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND up.role = 'admin')
  );

CREATE POLICY "Non-blocked users can vote" ON post_votes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );

CREATE POLICY "Non-blocked users can change own vote" ON post_votes
  FOR UPDATE USING (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );

CREATE POLICY "Non-blocked users can remove own vote" ON post_votes
  FOR DELETE USING (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );

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

CREATE TRIGGER trigger_update_post_vote_counts_insert
  AFTER INSERT ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

CREATE TRIGGER trigger_update_post_vote_counts_update
  AFTER UPDATE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

CREATE TRIGGER trigger_update_post_vote_counts_delete
  AFTER DELETE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_vote_counts();

-- =============================================================================
-- 4B. USER STATS (denormalized counters for admin views)
-- =============================================================================

CREATE OR REPLACE FUNCTION apply_user_stats_delta(
  p_user_id UUID,
  p_thread_delta BIGINT DEFAULT 0,
  p_post_delta BIGINT DEFAULT 0,
  p_deleted_delta BIGINT DEFAULT 0,
  p_flagged_delta BIGINT DEFAULT 0,
  p_upvotes_received_delta BIGINT DEFAULT 0,
  p_downvotes_received_delta BIGINT DEFAULT 0,
  p_upvotes_given_delta BIGINT DEFAULT 0,
  p_downvotes_given_delta BIGINT DEFAULT 0
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO user_stats (
    user_id,
    thread_count,
    post_count,
    deleted_count,
    flagged_count,
    upvotes_received,
    downvotes_received,
    upvotes_given,
    downvotes_given,
    updated_at
  )
  VALUES (
    p_user_id,
    p_thread_delta,
    p_post_delta,
    p_deleted_delta,
    p_flagged_delta,
    p_upvotes_received_delta,
    p_downvotes_received_delta,
    p_upvotes_given_delta,
    p_downvotes_given_delta,
    NOW()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    thread_count = GREATEST(user_stats.thread_count + EXCLUDED.thread_count, 0),
    post_count = GREATEST(user_stats.post_count + EXCLUDED.post_count, 0),
    deleted_count = GREATEST(user_stats.deleted_count + EXCLUDED.deleted_count, 0),
    flagged_count = GREATEST(user_stats.flagged_count + EXCLUDED.flagged_count, 0),
    upvotes_received = GREATEST(user_stats.upvotes_received + EXCLUDED.upvotes_received, 0),
    downvotes_received = GREATEST(user_stats.downvotes_received + EXCLUDED.downvotes_received, 0),
    upvotes_given = GREATEST(user_stats.upvotes_given + EXCLUDED.upvotes_given, 0),
    downvotes_given = GREATEST(user_stats.downvotes_given + EXCLUDED.downvotes_given, 0),
    updated_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION update_user_stats_on_thread_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM apply_user_stats_delta(NEW.author_id, 1, 0, 0, 0, 0, 0, 0, 0);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM apply_user_stats_delta(OLD.author_id, -1, 0, 0, 0, 0, 0, 0, 0);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_stats_thread_insert ON forum_threads;
CREATE TRIGGER trigger_update_user_stats_thread_insert
  AFTER INSERT ON forum_threads
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_thread_change();

DROP TRIGGER IF EXISTS trigger_update_user_stats_thread_delete ON forum_threads;
CREATE TRIGGER trigger_update_user_stats_thread_delete
  AFTER DELETE ON forum_threads
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_thread_change();

CREATE OR REPLACE FUNCTION update_user_stats_on_post_insert()
RETURNS TRIGGER AS $$
DECLARE
  v_deleted_delta BIGINT := 0;
  v_flagged_delta BIGINT := 0;
BEGIN
  IF COALESCE(NEW.is_deleted, FALSE) THEN
    v_deleted_delta := 1;
  END IF;
  IF COALESCE(NEW.is_flagged, FALSE) THEN
    v_flagged_delta := 1;
  END IF;

  PERFORM apply_user_stats_delta(NEW.author_id, 0, 1, v_deleted_delta, v_flagged_delta, 0, 0, 0, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_stats_on_post_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_deleted_delta BIGINT := 0;
  v_flagged_delta BIGINT := 0;
BEGIN
  IF COALESCE(OLD.is_deleted, FALSE) THEN
    v_deleted_delta := -1;
  END IF;
  IF COALESCE(OLD.is_flagged, FALSE) THEN
    v_flagged_delta := -1;
  END IF;

  PERFORM apply_user_stats_delta(OLD.author_id, 0, -1, v_deleted_delta, v_flagged_delta, 0, 0, 0, 0);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_stats_on_post_visibility()
RETURNS TRIGGER AS $$
DECLARE
  v_deleted_delta BIGINT := 0;
  v_flagged_delta BIGINT := 0;
BEGIN
  IF COALESCE(OLD.is_deleted, FALSE) <> COALESCE(NEW.is_deleted, FALSE) THEN
    v_deleted_delta := CASE WHEN COALESCE(NEW.is_deleted, FALSE) THEN 1 ELSE -1 END;
  END IF;

  IF COALESCE(OLD.is_flagged, FALSE) <> COALESCE(NEW.is_flagged, FALSE) THEN
    v_flagged_delta := CASE WHEN COALESCE(NEW.is_flagged, FALSE) THEN 1 ELSE -1 END;
  END IF;

  IF v_deleted_delta != 0 OR v_flagged_delta != 0 THEN
    PERFORM apply_user_stats_delta(NEW.author_id, 0, 0, v_deleted_delta, v_flagged_delta, 0, 0, 0, 0);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_stats_post_insert ON forum_posts;
CREATE TRIGGER trigger_update_user_stats_post_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_post_insert();

DROP TRIGGER IF EXISTS trigger_update_user_stats_post_delete ON forum_posts;
CREATE TRIGGER trigger_update_user_stats_post_delete
  AFTER DELETE ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_post_delete();

DROP TRIGGER IF EXISTS trigger_update_user_stats_post_visibility ON forum_posts;
CREATE TRIGGER trigger_update_user_stats_post_visibility
  AFTER UPDATE OF is_deleted, is_flagged ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_post_visibility();

CREATE OR REPLACE FUNCTION update_user_stats_on_vote_change()
RETURNS TRIGGER AS $$
DECLARE
  v_author_id UUID;
  v_up_received_delta BIGINT := 0;
  v_down_received_delta BIGINT := 0;
  v_up_given_delta BIGINT := 0;
  v_down_given_delta BIGINT := 0;
BEGIN
  SELECT author_id INTO v_author_id
  FROM forum_posts WHERE id = NEW.post_id;

  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 1 THEN
      v_up_received_delta := 1;
      v_up_given_delta := 1;
    ELSE
      v_down_received_delta := 1;
      v_down_given_delta := 1;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.vote_type = NEW.vote_type THEN
      RETURN NEW;
    END IF;

    IF OLD.vote_type = 1 THEN
      v_up_received_delta := v_up_received_delta - 1;
      v_up_given_delta := v_up_given_delta - 1;
    ELSE
      v_down_received_delta := v_down_received_delta - 1;
      v_down_given_delta := v_down_given_delta - 1;
    END IF;

    IF NEW.vote_type = 1 THEN
      v_up_received_delta := v_up_received_delta + 1;
      v_up_given_delta := v_up_given_delta + 1;
    ELSE
      v_down_received_delta := v_down_received_delta + 1;
      v_down_given_delta := v_down_given_delta + 1;
    END IF;
  END IF;

  IF v_author_id IS NOT NULL THEN
    PERFORM apply_user_stats_delta(
      v_author_id,
      0,
      0,
      0,
      0,
      v_up_received_delta,
      v_down_received_delta,
      0,
      0
    );
  END IF;

  PERFORM apply_user_stats_delta(
    NEW.user_id,
    0,
    0,
    0,
    0,
    0,
    0,
    v_up_given_delta,
    v_down_given_delta
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_stats_on_vote_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_author_id UUID;
  v_up_received_delta BIGINT := 0;
  v_down_received_delta BIGINT := 0;
  v_up_given_delta BIGINT := 0;
  v_down_given_delta BIGINT := 0;
BEGIN
  SELECT author_id INTO v_author_id
  FROM forum_posts WHERE id = OLD.post_id;

  IF OLD.vote_type = 1 THEN
    v_up_received_delta := -1;
    v_up_given_delta := -1;
  ELSE
    v_down_received_delta := -1;
    v_down_given_delta := -1;
  END IF;

  IF v_author_id IS NOT NULL THEN
    PERFORM apply_user_stats_delta(
      v_author_id,
      0,
      0,
      0,
      0,
      v_up_received_delta,
      v_down_received_delta,
      0,
      0
    );
  END IF;

  PERFORM apply_user_stats_delta(
    OLD.user_id,
    0,
    0,
    0,
    0,
    0,
    0,
    v_up_given_delta,
    v_down_given_delta
  );

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_stats_vote_insert ON post_votes;
CREATE TRIGGER trigger_update_user_stats_vote_insert
  AFTER INSERT ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_vote_change();

DROP TRIGGER IF EXISTS trigger_update_user_stats_vote_update ON post_votes;
CREATE TRIGGER trigger_update_user_stats_vote_update
  AFTER UPDATE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_vote_change();

DROP TRIGGER IF EXISTS trigger_update_user_stats_vote_delete ON post_votes;
CREATE TRIGGER trigger_update_user_stats_vote_delete
  AFTER DELETE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_user_stats_on_vote_delete();


-- =============================================================================
-- 5. BOOKMARKS
-- =============================================================================

CREATE TABLE IF NOT EXISTS bookmarks (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_created ON bookmarks(user_id, created_at DESC);

ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks" ON bookmarks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Non-blocked users can add bookmarks" ON bookmarks
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );

CREATE POLICY "Non-blocked users can remove own bookmarks" ON bookmarks
  FOR DELETE USING (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );


-- =============================================================================
-- 6. POLLS
-- =============================================================================

CREATE TABLE IF NOT EXISTS polls (
  id SERIAL PRIMARY KEY,
  thread_id INTEGER UNIQUE REFERENCES forum_threads(id) ON DELETE CASCADE,
  allow_multiple BOOLEAN DEFAULT FALSE,
  allow_vote_change BOOLEAN DEFAULT TRUE,
  show_results_before_vote BOOLEAN DEFAULT FALSE,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS poll_options (
  id SERIAL PRIMARY KEY,
  poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  option_text TEXT NOT NULL,
  display_order INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS poll_votes (
  id SERIAL PRIMARY KEY,
  poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  option_id INTEGER NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(poll_id, option_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON poll_options(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_option ON poll_votes(option_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_user ON poll_votes(poll_id, user_id);

ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view polls" ON polls FOR SELECT USING (true);
CREATE POLICY "Non-blocked users can create polls" ON polls
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND public.is_not_blocked());

CREATE POLICY "Anyone can view poll options" ON poll_options FOR SELECT USING (true);
CREATE POLICY "Non-blocked users can create poll options" ON poll_options
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND public.is_not_blocked());

CREATE POLICY "Anyone can view poll votes" ON poll_votes FOR SELECT USING (true);
CREATE POLICY "Non-blocked users can add own poll votes" ON poll_votes
  FOR INSERT WITH CHECK (auth.uid() = user_id AND public.is_not_blocked());
CREATE POLICY "Non-blocked users can remove own poll votes" ON poll_votes
  FOR DELETE USING (auth.uid() = user_id AND public.is_not_blocked());


-- =============================================================================
-- 7. MESSAGING (Chat)
-- =============================================================================

CREATE TABLE IF NOT EXISTS feedback_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_messages_user ON feedback_messages(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_recipient ON feedback_messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_unread ON feedback_messages(recipient_id, user_id, created_at DESC) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_feedback_messages_recipient_unread ON feedback_messages(recipient_id) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_feedback_messages_pair_created
  ON feedback_messages(user_id, recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_pair_created_reverse
  ON feedback_messages(recipient_id, user_id, created_at DESC);

ALTER TABLE feedback_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their conversations" ON feedback_messages
  FOR SELECT TO authenticated
  USING (
    feedback_messages.user_id = auth.uid()
    OR feedback_messages.recipient_id = auth.uid()
    OR public.check_is_admin()
  );

CREATE POLICY "Non-blocked users can send messages" ON feedback_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    feedback_messages.user_id = auth.uid()
    AND public.is_not_blocked()
  );

CREATE POLICY "Recipients can mark messages as read" ON feedback_messages
  FOR UPDATE TO authenticated
  USING (
    feedback_messages.recipient_id = auth.uid()
    OR public.check_is_admin()
  )
  WITH CHECK (
    feedback_messages.recipient_id = auth.uid()
    OR public.check_is_admin()
  );


-- =============================================================================
-- 8. IGNORED USERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS ignored_users (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ignored_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, ignored_user_id)
);

CREATE INDEX IF NOT EXISTS idx_ignored_users_user ON ignored_users(user_id);

ALTER TABLE ignored_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own ignored list" ON ignored_users
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Non-blocked users can add to ignored list" ON ignored_users
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );

CREATE POLICY "Non-blocked users can remove from ignored list" ON ignored_users
  FOR DELETE USING (
    auth.uid() = user_id
    AND public.is_not_blocked()
  );


-- =============================================================================
-- 9. FUNCTIONS - User Profile
-- =============================================================================

-- Reserved usernames list (single source of truth)
CREATE OR REPLACE FUNCTION get_reserved_usernames()
RETURNS TEXT[]
LANGUAGE sql
STABLE
AS $$
  SELECT ARRAY[
    -- System/admin terms (all blocked, including any containing 'admin' or 'moderator')
    'admin', 'admins', 'administrator', 'moderator', 'mod', 'system', 'root', 'superuser',
    'pandainunivmoderator', 'pandainunivmod',
    'support', 'help', 'helpdesk', 'staff', 'team', 'official',
    -- App-specific
    'panda', 'pandainuniv', 'panda_admin', 'pandaadmin',
    -- Common reserved
    'null', 'undefined', 'anonymous', 'guest', 'user', 'users',
    'account', 'accounts', 'profile', 'profiles', 'settings',
    'login', 'logout', 'signin', 'signout', 'signup', 'register',
    'api', 'app', 'www', 'mail', 'email', 'ftp', 'ssh',
    -- Content paths
    'about', 'contact', 'terms', 'privacy', 'tos', 'legal',
    'blog', 'news', 'forum', 'forums', 'discussion', 'chat',
    'home', 'index', 'main', 'dashboard', 'feed',
    -- Actions
    'create', 'edit', 'delete', 'new', 'search', 'explore',
    'bookmarked', 'bookmarks', 'saved', 'favorites',
    -- Search keywords (used as @op, @replies, @deleted, @flagged in search)
    'op', 'replies', 'deleted', 'flagged',
    -- Misc
    'test', 'demo', 'example', 'sample',
    'bot', 'robot', 'ai', 'claude', 'gpt', 'assistant'
  ]::TEXT[];
$$;

-- Get own profile status (role + blocked)
CREATE OR REPLACE FUNCTION get_my_profile_status()
RETURNS TABLE (
  role TEXT,
  is_blocked BOOLEAN
)
LANGUAGE sql SECURITY DEFINER SET search_path = public
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
LANGUAGE sql SECURITY DEFINER SET search_path = public
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
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT b.post_id
  FROM bookmarks b
  WHERE b.user_id = auth.uid()
    AND b.post_id = ANY(p_post_ids);
$$;

-- Get current user's vote + bookmark overlay for a list of posts
CREATE OR REPLACE FUNCTION get_user_post_overlays(p_post_ids INTEGER[])
RETURNS TABLE (
  post_id INTEGER,
  vote_type INTEGER,
  is_bookmarked BOOLEAN
)
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT
    pid AS post_id,
    pv.vote_type,
    (b.post_id IS NOT NULL) AS is_bookmarked
  FROM unnest(p_post_ids) AS pid
  LEFT JOIN post_votes pv
    ON pv.post_id = pid
    AND pv.user_id = auth.uid()
  LEFT JOIN bookmarks b
    ON b.post_id = pid
    AND b.user_id = auth.uid()
  WHERE auth.uid() IS NOT NULL;
$$;

-- Update own login metadata (last login/IP/location)
CREATE OR REPLACE FUNCTION update_login_metadata(
  p_last_login TIMESTAMPTZ DEFAULT NULL,
  p_last_ip INET DEFAULT NULL,
  p_last_location TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

-- Public profile lookup (no auth required, returns safe fields only)
CREATE OR REPLACE FUNCTION get_public_user_profile(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  username TEXT,
  avatar_url TEXT,
  avatar_path TEXT,
  is_private BOOLEAN
)
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT up.id, up.username, up.avatar_url, up.avatar_path, up.is_private
  FROM user_profiles up
  WHERE up.id = p_user_id;
$$;

-- Get public user stats (with privacy check)
CREATE OR REPLACE FUNCTION get_public_user_stats(p_user_id UUID)
RETURNS TABLE (
  is_private BOOLEAN,
  thread_count BIGINT,
  post_count BIGINT,
  upvotes_received BIGINT,
  downvotes_received BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_private BOOLEAN;
  v_is_admin BOOLEAN;
  v_current_user_id UUID;
BEGIN
  v_current_user_id := auth.uid();

  -- Check if target user is private
  SELECT COALESCE(up.is_private, FALSE) INTO v_is_private
  FROM user_profiles up WHERE up.id = p_user_id;

  -- Check if current user is admin
  v_is_admin := public.check_is_admin(v_current_user_id);

  -- If private and not self and not admin, return empty stats with is_private = true
  IF v_is_private AND p_user_id != v_current_user_id AND NOT v_is_admin THEN
    RETURN QUERY SELECT TRUE::BOOLEAN, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(v_is_private, FALSE),
    -- Count threads where OP is not deleted
    (SELECT COUNT(*) FROM forum_threads t
     JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
     WHERE t.author_id = p_user_id AND COALESCE(op.is_deleted, false) = false),
    -- Count replies only (posts with parent_id, not thread OPs)
    (SELECT COUNT(*) FROM forum_posts
     WHERE author_id = p_user_id
     AND parent_id IS NOT NULL
     AND COALESCE(is_deleted, false) = false),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0)
     FROM post_votes pv JOIN forum_posts fp ON pv.post_id = fp.id WHERE fp.author_id = p_user_id),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0)
     FROM post_votes pv JOIN forum_posts fp ON pv.post_id = fp.id WHERE fp.author_id = p_user_id);
END;
$$;

-- Check username availability (case-insensitive + reserved words)
CREATE OR REPLACE FUNCTION is_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.check_is_admin() THEN
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE user_profiles SET is_blocked = p_is_blocked WHERE id = p_user_id;
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION get_public_user_profile(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_public_user_stats(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_my_profile_status() TO authenticated;
GRANT EXECUTE ON FUNCTION update_login_metadata(TIMESTAMPTZ, INET, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_post_votes(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_post_bookmarks(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_post_overlays(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION is_username_available(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION set_user_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION set_user_blocked(UUID, BOOLEAN) TO authenticated;

-- Admin: Get all users with stats (legacy - kept for compatibility)
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Check admin
  IF NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
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
    COALESCE(us.thread_count, 0),
    GREATEST(COALESCE(us.post_count, 0) - COALESCE(us.thread_count, 0), 0),
    COALESCE(us.flagged_count, 0)
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  LEFT JOIN user_stats us ON us.user_id = up.id
  ORDER BY up.created_at DESC;
END;
$$;

-- Admin: Get paginated users with full stats (sorted by recent activity)
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total BIGINT;
  v_search_pattern TEXT;
BEGIN
  -- Check admin
  IF NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- Prepare search pattern (supports @username syntax)
  IF p_search IS NOT NULL AND p_search != '' THEN
    IF LEFT(p_search, 1) = '@' THEN
      v_search_pattern := '%' || LOWER(SUBSTRING(p_search FROM 2)) || '%';
    ELSE
      v_search_pattern := '%' || LOWER(p_search) || '%';
    END IF;
  END IF;

  -- Count total matching users
  SELECT COUNT(*) INTO v_total
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  WHERE (v_search_pattern IS NULL
    OR LOWER(up.username) LIKE v_search_pattern
    OR LOWER(au.email::TEXT) LIKE v_search_pattern);

  RETURN QUERY
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
    COALESCE(us.thread_count, 0),
    COALESCE(us.post_count, 0),
    COALESCE(us.deleted_count, 0),
    COALESCE(us.flagged_count, 0),
    COALESCE(us.upvotes_received, 0),
    COALESCE(us.downvotes_received, 0),
    COALESCE(us.upvotes_given, 0),
    COALESCE(us.downvotes_given, 0),
    v_total
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  LEFT JOIN user_stats us ON us.user_id = up.id
  WHERE (v_search_pattern IS NULL
    OR LOWER(up.username) LIKE v_search_pattern
    OR LOWER(au.email::TEXT) LIKE v_search_pattern)
  ORDER BY up.last_login DESC NULLS LAST, up.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


-- =============================================================================
-- 10. FUNCTIONS - Forum Threads
-- =============================================================================

-- Create thread with first post
CREATE OR REPLACE FUNCTION create_thread(
  p_title TEXT,
  p_category_id INTEGER,
  p_content TEXT,
  p_is_flagged BOOLEAN DEFAULT FALSE,
  p_flag_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_thread_id INTEGER;
  v_post_id INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Create thread
  INSERT INTO forum_threads (title, category_id, author_id, is_flagged, flag_reason)
  VALUES (p_title, p_category_id, auth.uid(), p_is_flagged, p_flag_reason)
  RETURNING id INTO v_thread_id;

  -- Create first post (OP)
  INSERT INTO forum_posts (thread_id, author_id, content, is_flagged, flag_reason)
  VALUES (v_thread_id, auth.uid(), p_content, p_is_flagged, p_flag_reason)
  RETURNING id INTO v_post_id;

  -- Auto-upvote own post
  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_thread_id;
END;
$$;

-- Get paginated forum threads
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
  has_poll BOOLEAN,
  is_op_deleted BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_is_admin := public.check_is_admin();

  -- Count total matching threads
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

  -- Use subquery to compute values once, then reference aliases in ORDER BY
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
      COALESCE(op.reply_count, 0)::BIGINT AS reply_count,
      COALESCE(op.likes, 0)::BIGINT AS total_likes,
      COALESCE(op.dislikes, 0)::BIGINT AS total_dislikes,
      EXISTS (SELECT 1 FROM polls pl WHERE pl.thread_id = t.id) AS has_poll,
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


-- =============================================================================
-- 11. FUNCTIONS - Forum Posts
-- =============================================================================

-- Get a single post by ID (used to resolve stub posts in replies view)
CREATE OR REPLACE FUNCTION get_post_by_id(p_post_id INTEGER)
RETURNS TABLE (
  id INTEGER,
  thread_id INTEGER,
  parent_id INTEGER,
  author_id UUID,
  author_name TEXT,
  author_avatar TEXT,
  author_avatar_path TEXT,
  content TEXT,
  additional_comments TEXT,
  created_at TIMESTAMPTZ,
  edited_at TIMESTAMPTZ,
  likes BIGINT,
  dislikes BIGINT,
  user_vote INTEGER,
  reply_count BIGINT,
  is_flagged BOOLEAN,
  flag_reason TEXT,
  is_deleted BOOLEAN,
  deleted_by UUID,
  is_author_deleted BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  v_is_admin := public.check_is_admin();

  RETURN QUERY
  SELECT
    p.id,
    p.thread_id,
    p.parent_id,
    p.author_id,
    u.username,
    u.avatar_url,
    u.avatar_path,
    p.content,
    p.additional_comments,
    p.created_at,
    p.edited_at,
    COALESCE(p.likes, 0) AS likes,
    COALESCE(p.dislikes, 0) AS dislikes,
    (SELECT pv.vote_type FROM post_votes pv WHERE pv.post_id = p.id AND pv.user_id = auth.uid()),
    COALESCE(p.reply_count, 0),
    p.is_flagged,
    p.flag_reason,
    COALESCE(p.is_deleted, FALSE),
    p.deleted_by,
    COALESCE(u.is_deleted, FALSE)
  FROM forum_posts p
  JOIN user_profiles u ON u.id = p.author_id
  WHERE p.id = p_post_id
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);
END;
$$;

-- Add reply to thread
CREATE OR REPLACE FUNCTION add_reply(
  p_thread_id INTEGER,
  p_content TEXT,
  p_parent_id INTEGER DEFAULT NULL,
  p_is_flagged BOOLEAN DEFAULT FALSE,
  p_flag_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

  -- Auto-upvote own post
  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_post_id;
END;
$$;

-- Get paginated thread posts
CREATE OR REPLACE FUNCTION get_paginated_thread_posts(
  p_thread_id INTEGER,
  p_parent_id INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort TEXT DEFAULT 'popular'
)
RETURNS TABLE (
  id INTEGER,
  thread_id INTEGER,
  parent_id INTEGER,
  author_id UUID,
  author_name TEXT,
  author_avatar TEXT,
  author_avatar_path TEXT,
  content TEXT,
  additional_comments TEXT,
  created_at TIMESTAMPTZ,
  edited_at TIMESTAMPTZ,
  likes BIGINT,
  dislikes BIGINT,
  user_vote INTEGER,
  reply_count BIGINT,
  is_flagged BOOLEAN,
  flag_reason TEXT,
  is_deleted BOOLEAN,
  deleted_by UUID,
  is_author_deleted BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
BEGIN
  v_is_admin := public.check_is_admin();

  -- Count total posts
  SELECT COUNT(*) INTO v_total
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id
    AND (p_parent_id IS NULL AND p.parent_id IS NULL OR p.parent_id = p_parent_id)
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);

  -- Use subquery to compute values once, then reference aliases in ORDER BY
  RETURN QUERY
  SELECT * FROM (
    SELECT
      p.id,
      p.thread_id,
      p.parent_id,
      p.author_id,
      u.username,
      u.avatar_url,
      u.avatar_path,
      p.content,
      p.additional_comments,
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
      COALESCE(u.is_deleted, FALSE) AS is_author_deleted,
      v_total AS total_count
    FROM forum_posts p
    JOIN user_profiles u ON u.id = p.author_id
    WHERE p.thread_id = p_thread_id
      AND (p_parent_id IS NULL AND p.parent_id IS NULL OR p.parent_id = p_parent_id)
      AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
  ) sub
  ORDER BY
    CASE WHEN p_sort = 'popular' THEN sub.likes END DESC,
    CASE WHEN p_sort = 'popular' THEN sub.reply_count END DESC,
    CASE WHEN p_sort = 'new' THEN sub.created_at END DESC,
    sub.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Get thread view: OP + paginated replies in a single query (eliminates waterfall)
-- Returns: is_op = TRUE for the original post, is_op = FALSE for replies
-- First row is always the OP, followed by paginated replies sorted by p_sort
CREATE OR REPLACE FUNCTION get_thread_view(
  p_thread_id INTEGER,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort TEXT DEFAULT 'popular'
)
RETURNS TABLE (
  id INTEGER,
  thread_id INTEGER,
  parent_id INTEGER,
  author_id UUID,
  author_name TEXT,
  author_avatar TEXT,
  author_avatar_path TEXT,
  content TEXT,
  additional_comments TEXT,
  created_at TIMESTAMPTZ,
  edited_at TIMESTAMPTZ,
  likes BIGINT,
  dislikes BIGINT,
  user_vote INTEGER,
  reply_count BIGINT,
  is_flagged BOOLEAN,
  flag_reason TEXT,
  is_deleted BOOLEAN,
  deleted_by UUID,
  is_author_deleted BOOLEAN,
  is_op BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_op_id INTEGER;
  v_total BIGINT;
BEGIN
  v_is_admin := public.check_is_admin();

  -- Get the OP's ID (the post with parent_id = NULL for this thread)
  SELECT p.id INTO v_op_id
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id AND p.parent_id IS NULL
  LIMIT 1;

  -- If no OP found, return empty
  IF v_op_id IS NULL THEN
    RETURN;
  END IF;

  -- Count total replies to the OP (for pagination)
  SELECT COUNT(*) INTO v_total
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id
    AND p.parent_id = v_op_id
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);

  -- First, return the OP (always first, marked with is_op = TRUE)
  RETURN QUERY
  SELECT
    p.id,
    p.thread_id,
    p.parent_id,
    p.author_id,
    u.username,
    u.avatar_url,
    u.avatar_path,
    p.content,
    p.additional_comments,
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
    COALESCE(u.is_deleted, FALSE) AS is_author_deleted,
    TRUE AS is_op,
    v_total AS total_count
  FROM forum_posts p
  JOIN user_profiles u ON u.id = p.author_id
  WHERE p.id = v_op_id;

  -- Then, return paginated replies to the OP (marked with is_op = FALSE)
  RETURN QUERY
  SELECT * FROM (
    SELECT
      p.id,
      p.thread_id,
      p.parent_id,
      p.author_id,
      u.username,
      u.avatar_url,
      u.avatar_path,
      p.content,
      p.additional_comments,
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
      COALESCE(u.is_deleted, FALSE) AS is_author_deleted,
      FALSE AS is_op,
      v_total AS total_count
    FROM forum_posts p
    JOIN user_profiles u ON u.id = p.author_id
    WHERE p.thread_id = p_thread_id
      AND p.parent_id = v_op_id
      AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
  ) sub
  ORDER BY
    CASE WHEN p_sort = 'popular' THEN sub.likes END DESC,
    CASE WHEN p_sort = 'popular' THEN sub.reply_count END DESC,
    CASE WHEN p_sort = 'new' THEN sub.created_at END DESC,
    sub.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Delete/undelete post
CREATE OR REPLACE FUNCTION delete_post(p_post_id INTEGER)
RETURNS TABLE (success BOOLEAN, message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

  v_is_admin := public.check_is_admin();

  -- Check permission: author or admin
  IF v_post.author_id != auth.uid() AND NOT v_is_admin THEN
    RETURN QUERY SELECT FALSE, 'Permission denied'::TEXT;
    RETURN;
  END IF;

  -- Toggle deletion
  IF COALESCE(v_post.is_deleted, FALSE) THEN
    -- Undelete (admin only)
    IF NOT v_is_admin THEN
      RETURN QUERY SELECT FALSE, 'Only admins can restore deleted posts'::TEXT;
      RETURN;
    END IF;
    UPDATE forum_posts SET is_deleted = FALSE, deleted_by = NULL WHERE forum_posts.id = p_post_id;
    RETURN QUERY SELECT TRUE, 'Post restored'::TEXT;
  ELSE
    -- Delete
    UPDATE forum_posts SET is_deleted = TRUE, deleted_by = auth.uid() WHERE forum_posts.id = p_post_id;
    RETURN QUERY SELECT TRUE, 'Post deleted'::TEXT;
  END IF;
END;
$$;

-- Edit post
CREATE OR REPLACE FUNCTION edit_post(
  p_post_id INTEGER,
  p_content TEXT DEFAULT NULL,
  p_additional_comments TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, can_edit_content BOOLEAN, message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

  -- Can edit content within 15 minutes
  v_can_edit_content := (NOW() - v_post.created_at) < INTERVAL '15 minutes';

  IF p_content IS NOT NULL THEN
    IF NOT v_can_edit_content THEN
      RETURN QUERY SELECT FALSE, FALSE, 'Content edit window expired (15 minutes)'::TEXT;
      RETURN;
    END IF;
    UPDATE forum_posts SET content = p_content, edited_at = NOW() WHERE forum_posts.id = p_post_id;
  END IF;

  IF p_additional_comments IS NOT NULL THEN
    -- Append new comment with timestamp to existing comments
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

-- Vote on post
CREATE OR REPLACE FUNCTION vote_post(p_post_id INTEGER, p_vote_type INTEGER)
RETURNS TABLE (likes BIGINT, dislikes BIGINT, user_vote INTEGER)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_existing_vote INTEGER;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT vote_type INTO v_existing_vote FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();

  IF p_vote_type = 0 THEN
    -- Remove vote
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSIF v_existing_vote IS NULL THEN
    -- New vote
    INSERT INTO post_votes (post_id, user_id, vote_type) VALUES (p_post_id, auth.uid(), p_vote_type);
  ELSIF v_existing_vote = p_vote_type THEN
    -- Same vote, remove it
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSE
    -- Change vote
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


-- =============================================================================
-- 12. FUNCTIONS - Moderation
-- =============================================================================

-- Toggle post flagged status (admin only)
CREATE OR REPLACE FUNCTION toggle_post_flagged(p_post_id INTEGER)
RETURNS TABLE (success BOOLEAN, is_flagged BOOLEAN, message TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_current_flagged BOOLEAN;
BEGIN
  v_is_admin := public.check_is_admin();

  IF NOT v_is_admin THEN
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

-- Get flagged posts (admin only)
CREATE OR REPLACE FUNCTION get_flagged_posts(p_limit INTEGER DEFAULT 50, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
  id INTEGER,
  thread_id INTEGER,
  thread_title TEXT,
  parent_id INTEGER,
  content TEXT,
  author_id UUID,
  author_name TEXT,
  author_avatar TEXT,
  author_avatar_path TEXT,
  created_at TIMESTAMPTZ,
  flag_reason TEXT,
  is_thread_op BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  IF NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT COUNT(*) INTO v_total FROM forum_posts WHERE is_flagged = TRUE;

  RETURN QUERY
  SELECT
    p.id,
    p.thread_id,
    t.title,
    p.parent_id,
    p.content,
    p.author_id,
    u.username,
    u.avatar_url,
    u.avatar_path,
    p.created_at,
    p.flag_reason,
    (p.parent_id IS NULL),
    v_total
  FROM forum_posts p
  JOIN forum_threads t ON t.id = p.thread_id
  JOIN user_profiles u ON u.id = p.author_id
  WHERE p.is_flagged = TRUE
  ORDER BY p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


-- =============================================================================
-- 13. FUNCTIONS - Polls
-- =============================================================================

-- Create thread with poll
CREATE OR REPLACE FUNCTION create_poll_thread(
  p_title TEXT,
  p_content TEXT,
  p_poll_options TEXT[],
  p_allow_multiple BOOLEAN DEFAULT FALSE,
  p_duration_hours INTEGER DEFAULT 0,
  p_is_flagged BOOLEAN DEFAULT FALSE,
  p_flag_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_thread_id INTEGER;
  v_poll_id INTEGER;
  v_option TEXT;
  v_order INTEGER := 0;
  v_ends_at TIMESTAMPTZ := NULL;
BEGIN
  -- Calculate ends_at if duration specified
  IF p_duration_hours > 0 THEN
    v_ends_at := NOW() + (p_duration_hours || ' hours')::INTERVAL;
  END IF;

  -- Create thread
  v_thread_id := create_thread(p_title, NULL, p_content, p_is_flagged, p_flag_reason);

  -- Create poll
  INSERT INTO polls (thread_id, allow_multiple, allow_vote_change, show_results_before_vote, ends_at)
  VALUES (v_thread_id, p_allow_multiple, TRUE, FALSE, v_ends_at)
  RETURNING id INTO v_poll_id;

  -- Create options
  FOREACH v_option IN ARRAY p_poll_options LOOP
    INSERT INTO poll_options (poll_id, option_text, display_order)
    VALUES (v_poll_id, v_option, v_order);
    v_order := v_order + 1;
  END LOOP;

  RETURN v_thread_id;
END;
$$;

-- Get poll data
CREATE OR REPLACE FUNCTION get_poll_data(p_thread_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_poll polls%ROWTYPE;
  v_user_votes INTEGER[];
  v_has_voted BOOLEAN;
  v_result JSON;
BEGIN
  SELECT * INTO v_poll FROM polls WHERE thread_id = p_thread_id;

  IF v_poll IS NULL THEN
    RETURN NULL;
  END IF;

  -- Get user's votes
  SELECT ARRAY_AGG(option_id) INTO v_user_votes
  FROM poll_votes WHERE poll_id = v_poll.id AND user_id = auth.uid();

  v_has_voted := v_user_votes IS NOT NULL AND array_length(v_user_votes, 1) > 0;

  SELECT json_build_object(
    'id', v_poll.id,
    'allow_multiple', v_poll.allow_multiple,
    'allow_vote_change', v_poll.allow_vote_change,
    'show_results_before_vote', v_poll.show_results_before_vote,
    'ends_at', v_poll.ends_at,
    'has_voted', v_has_voted,
    'user_votes', COALESCE(v_user_votes, ARRAY[]::INTEGER[]),
    'total_votes', (SELECT COUNT(DISTINCT user_id) FROM poll_votes WHERE poll_id = v_poll.id),
    'options', (
      SELECT json_agg(json_build_object(
        'id', po.id,
        'text', po.option_text,
        'vote_count', (SELECT COUNT(*) FROM poll_votes pv WHERE pv.option_id = po.id)
      ) ORDER BY po.display_order)
      FROM poll_options po WHERE po.poll_id = v_poll.id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Vote on poll
CREATE OR REPLACE FUNCTION vote_poll(p_poll_id INTEGER, p_option_ids INTEGER[])
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

  -- Check if poll has ended
  IF v_poll.ends_at IS NOT NULL AND v_poll.ends_at < NOW() THEN
    RAISE EXCEPTION 'Poll has ended';
  END IF;

  -- Check if user already voted and vote change not allowed
  IF NOT v_poll.allow_vote_change AND EXISTS (SELECT 1 FROM poll_votes WHERE poll_id = p_poll_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Vote change not allowed';
  END IF;

  -- Check multiple votes
  IF NOT v_poll.allow_multiple AND array_length(p_option_ids, 1) > 1 THEN
    RAISE EXCEPTION 'Multiple votes not allowed';
  END IF;

  -- Remove existing votes
  DELETE FROM poll_votes WHERE poll_id = p_poll_id AND user_id = auth.uid();

  -- Add new votes
  FOREACH v_option_id IN ARRAY p_option_ids LOOP
    INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES (p_poll_id, v_option_id, auth.uid());
  END LOOP;

  -- Return updated poll data
  SELECT thread_id INTO v_thread_id FROM polls WHERE id = p_poll_id;
  RETURN get_poll_data(v_thread_id);
END;
$$;

GRANT EXECUTE ON FUNCTION create_poll_thread(TEXT, TEXT, TEXT[], BOOLEAN, INTEGER, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_poll_data(INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION vote_poll(INTEGER, INTEGER[]) TO authenticated;


-- =============================================================================
-- 14. FUNCTIONS - Messaging
-- =============================================================================

-- Get user conversations
CREATE OR REPLACE FUNCTION get_user_conversations(p_user_id UUID)
RETURNS TABLE (
  conversation_partner_id UUID,
  partner_username TEXT,
  partner_avatar TEXT,
  partner_avatar_path TEXT,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  last_message_is_from_me BOOLEAN,
  unread_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id <> auth.uid() AND NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN QUERY
  WITH conversations AS (
    SELECT DISTINCT
      CASE WHEN user_id = p_user_id THEN recipient_id ELSE user_id END AS partner_id
    FROM feedback_messages
    WHERE user_id = p_user_id OR recipient_id = p_user_id
  ),
  last_messages AS (
    SELECT DISTINCT ON (
      CASE WHEN fm.user_id = p_user_id THEN fm.recipient_id ELSE fm.user_id END
    )
      CASE WHEN fm.user_id = p_user_id THEN fm.recipient_id ELSE fm.user_id END AS partner_id,
      fm.content,
      fm.created_at,
      fm.user_id = p_user_id AS is_from_me
    FROM feedback_messages fm
    WHERE fm.user_id = p_user_id OR fm.recipient_id = p_user_id
    ORDER BY
      CASE WHEN fm.user_id = p_user_id THEN fm.recipient_id ELSE fm.user_id END,
      fm.created_at DESC
  ),
  unread_counts AS (
    SELECT fm.user_id AS partner_id, COUNT(*) AS unread_count
    FROM feedback_messages fm
    WHERE fm.recipient_id = p_user_id
      AND fm.is_read = FALSE
    GROUP BY fm.user_id
  )
  SELECT
    c.partner_id,
    u.username,
    u.avatar_url,
    u.avatar_path,
    lm.content,
    lm.created_at,
    lm.is_from_me,
    COALESCE(uc.unread_count, 0)
  FROM conversations c
  JOIN user_profiles u ON u.id = c.partner_id
  JOIN last_messages lm ON lm.partner_id = c.partner_id
  LEFT JOIN unread_counts uc ON uc.partner_id = c.partner_id
  WHERE NOT COALESCE(u.is_deleted, FALSE)
  ORDER BY lm.created_at DESC;
END;
$$;

-- Get conversation messages
CREATE OR REPLACE FUNCTION get_conversation_messages(
  p_user_id UUID,
  p_partner_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_before_cursor TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  recipient_id UUID,
  content TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ,
  sender_username TEXT,
  sender_avatar TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id <> auth.uid() AND NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN QUERY
  SELECT
    fm.id AS id,
    fm.user_id AS user_id,
    fm.recipient_id AS recipient_id,
    fm.content AS content,
    fm.is_read AS is_read,
    fm.created_at AS created_at,
    u.username AS sender_username,
    u.avatar_url AS sender_avatar
  FROM feedback_messages fm
  JOIN user_profiles u ON u.id = fm.user_id
  WHERE ((fm.user_id = p_user_id AND fm.recipient_id = p_partner_id)
      OR (fm.user_id = p_partner_id AND fm.recipient_id = p_user_id))
    AND (p_before_cursor IS NULL OR fm.created_at < p_before_cursor)
  ORDER BY fm.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Get unread message count
CREATE OR REPLACE FUNCTION get_unread_message_count(p_user_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id <> auth.uid() AND NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN (SELECT COUNT(*) FROM feedback_messages WHERE recipient_id = p_user_id AND is_read = FALSE);
END;
$$;

-- Mark conversation as read
CREATE OR REPLACE FUNCTION mark_conversation_read(p_user_id UUID, p_partner_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id <> auth.uid() AND NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  UPDATE feedback_messages
  SET is_read = TRUE
  WHERE recipient_id = p_user_id AND user_id = p_partner_id AND is_read = FALSE;
END;
$$;

-- Grant execute on messaging functions
GRANT EXECUTE ON FUNCTION get_user_conversations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversation_messages(UUID, UUID, INTEGER, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_message_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_conversation_read(UUID, UUID) TO authenticated;


-- =============================================================================
-- 15. FUNCTIONS - Ignored Users
-- =============================================================================

-- Toggle ignore user
CREATE OR REPLACE FUNCTION toggle_ignore_user(p_ignored_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

-- Get ignored users list
CREATE OR REPLACE FUNCTION get_ignored_users()
RETURNS TABLE (ignored_user_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT iu.ignored_user_id FROM ignored_users iu WHERE iu.user_id = auth.uid();
END;
$$;

-- Check if user is ignored
CREATE OR REPLACE FUNCTION is_user_ignored(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM ignored_users WHERE user_id = auth.uid() AND ignored_user_id = p_user_id);
END;
$$;


-- =============================================================================
-- 16. FUNCTIONS - Bookmarks
-- =============================================================================


-- =============================================================================
-- POST BOOKMARKS (view for frontend compatibility)
-- =============================================================================
CREATE OR REPLACE VIEW post_bookmarks AS
SELECT id, user_id, post_id, created_at FROM bookmarks;

-- Get user's bookmarked post IDs (excluding deleted posts)
CREATE OR REPLACE FUNCTION get_user_bookmark_post_ids(p_user_id UUID)
RETURNS INTEGER[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
STABLE
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_post_ids INTEGER[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_is_admin := public.check_is_admin();

  IF NOT v_is_admin AND p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT COALESCE(ARRAY_AGG(b.post_id), ARRAY[]::INTEGER[]) INTO v_post_ids
  FROM bookmarks b
  JOIN forum_posts p ON p.id = b.post_id
  WHERE b.user_id = p_user_id
    AND COALESCE(p.is_deleted, false) = false;

  RETURN v_post_ids;
END;
$$;

-- Toggle thread bookmark (bookmarks the OP post of a thread)
CREATE OR REPLACE FUNCTION toggle_thread_bookmark(p_thread_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

-- Toggle post bookmark
CREATE OR REPLACE FUNCTION toggle_post_bookmark(p_post_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

-- Get bookmarked thread IDs (threads where OP is bookmarked)
CREATE OR REPLACE FUNCTION get_bookmarked_thread_ids(p_user_id UUID)
RETURNS SETOF INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_is_admin := public.check_is_admin();

  IF NOT v_is_admin AND p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN QUERY
  SELECT DISTINCT p.thread_id
  FROM bookmarks b
  JOIN forum_posts p ON p.id = b.post_id
  WHERE b.user_id = p_user_id
    AND p.parent_id IS NULL;
END;
$$;

-- Get paginated bookmarked posts with optional search
CREATE OR REPLACE FUNCTION get_bookmarked_posts(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_search_text TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_posts JSON;
  v_total BIGINT;
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_is_admin := public.check_is_admin();

  IF NOT v_is_admin AND p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

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

-- =============================================================================
-- AUTHOR POSTS SEARCH
-- =============================================================================
CREATE OR REPLACE FUNCTION get_posts_by_author(
  p_author_username TEXT DEFAULT NULL,
  p_search_text TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_flagged_only BOOLEAN DEFAULT FALSE,
  p_deleted_only BOOLEAN DEFAULT FALSE,
  p_post_type TEXT DEFAULT NULL  -- NULL/'all' = all posts, 'op' = thread OPs only, 'replies' = replies only
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

  v_is_admin := public.check_is_admin(v_current_user_id);
  SELECT username INTO v_current_username
  FROM user_profiles WHERE id = v_current_user_id;

  -- Handle @username search with privacy check
  IF p_author_username IS NOT NULL AND p_author_username != '' THEN
    SELECT id, COALESCE(is_private, FALSE) INTO v_author_id, v_author_is_private
    FROM user_profiles WHERE LOWER(username) = LOWER(p_author_username);

    -- User not found
    IF v_author_id IS NULL THEN
      RETURN json_build_object('posts', '[]'::JSON, 'total_count', 0, 'is_private', FALSE);
    END IF;

    -- Privacy check: private users can only be searched by admins or themselves
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
    -- Filter by post type: 'op' = thread OPs only, 'replies' = replies only
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
      -- Filter by post type: 'op' = thread OPs only, 'replies' = replies only
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


-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

-- Notifications table
-- Aggregates votes AND replies to a specific post (one notification per post)
-- Stores current counts and baseline counts (from last dismissal) to calculate "new" activity
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
  thread_id INTEGER NOT NULL REFERENCES forum_threads(id) ON DELETE CASCADE,
  -- Current total counts
  reply_count INTEGER DEFAULT 0,
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  -- Baseline counts (set when notification is dismissed, used to calculate "new" counts)
  baseline_reply_count INTEGER DEFAULT 0,
  baseline_upvotes INTEGER DEFAULT 0,
  baseline_downvotes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_post ON notifications(post_id);

-- RLS for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE USING (auth.uid() = user_id);

-- Trigger: notify on reply insert (incremental)
CREATE OR REPLACE FUNCTION notify_on_reply_insert()
RETURNS TRIGGER AS $$
DECLARE
  v_parent_author_id UUID;
BEGIN
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT author_id INTO v_parent_author_id
  FROM forum_posts WHERE id = NEW.parent_id;

  IF v_parent_author_id IS NULL OR v_parent_author_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO notifications (user_id, post_id, thread_id, reply_count)
  VALUES (v_parent_author_id, NEW.parent_id, NEW.thread_id, 1)
  ON CONFLICT (user_id, post_id)
  DO UPDATE SET
    reply_count = notifications.reply_count + 1,
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger: notify on reply visibility change (soft delete/restore)
CREATE OR REPLACE FUNCTION notify_on_reply_visibility()
RETURNS TRIGGER AS $$
DECLARE
  v_parent_author_id UUID;
  v_delta INTEGER;
BEGIN
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF COALESCE(OLD.is_deleted, FALSE) = COALESCE(NEW.is_deleted, FALSE) THEN
    RETURN NEW;
  END IF;

  v_delta := CASE WHEN COALESCE(NEW.is_deleted, FALSE) THEN -1 ELSE 1 END;

  SELECT author_id INTO v_parent_author_id
  FROM forum_posts WHERE id = NEW.parent_id;

  IF v_parent_author_id IS NULL OR v_parent_author_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  IF v_delta > 0 THEN
    INSERT INTO notifications (user_id, post_id, thread_id, reply_count)
    VALUES (v_parent_author_id, NEW.parent_id, NEW.thread_id, 1)
    ON CONFLICT (user_id, post_id)
    DO UPDATE SET
      reply_count = notifications.reply_count + 1,
      updated_at = NOW();
  ELSE
    UPDATE notifications
    SET reply_count = GREATEST(reply_count - 1, 0),
        updated_at = NOW()
    WHERE user_id = v_parent_author_id AND post_id = NEW.parent_id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger: notify on reply hard delete (defensive)
CREATE OR REPLACE FUNCTION notify_on_reply_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_parent_author_id UUID;
BEGIN
  IF OLD.parent_id IS NULL THEN
    RETURN OLD;
  END IF;

  IF COALESCE(OLD.is_deleted, FALSE) = TRUE THEN
    RETURN OLD;
  END IF;

  SELECT author_id INTO v_parent_author_id
  FROM forum_posts WHERE id = OLD.parent_id;

  IF v_parent_author_id IS NULL OR v_parent_author_id = OLD.author_id THEN
    RETURN OLD;
  END IF;

  UPDATE notifications
  SET reply_count = GREATEST(reply_count - 1, 0),
      updated_at = NOW()
  WHERE user_id = v_parent_author_id AND post_id = OLD.parent_id;

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_on_reply_insert ON forum_posts;
CREATE TRIGGER trigger_notify_on_reply_insert
  AFTER INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_reply_insert();

DROP TRIGGER IF EXISTS trigger_notify_on_reply_visibility ON forum_posts;
CREATE TRIGGER trigger_notify_on_reply_visibility
  AFTER UPDATE OF is_deleted ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_reply_visibility();

DROP TRIGGER IF EXISTS trigger_notify_on_reply_delete ON forum_posts;
CREATE TRIGGER trigger_notify_on_reply_delete
  AFTER DELETE ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_reply_delete();

-- Trigger: notify on vote change (incremental)
CREATE OR REPLACE FUNCTION notify_on_vote_change()
RETURNS TRIGGER AS $$
DECLARE
  v_post_author_id UUID;
  v_thread_id INTEGER;
  v_up_delta INTEGER := 0;
  v_down_delta INTEGER := 0;
BEGIN
  SELECT author_id, thread_id INTO v_post_author_id, v_thread_id
  FROM forum_posts WHERE id = NEW.post_id;

  IF v_post_author_id IS NULL OR v_post_author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 1 THEN
      v_up_delta := 1;
    ELSE
      v_down_delta := 1;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.vote_type = NEW.vote_type THEN
      RETURN NEW;
    END IF;

    IF OLD.vote_type = 1 THEN
      v_up_delta := v_up_delta - 1;
    ELSE
      v_down_delta := v_down_delta - 1;
    END IF;

    IF NEW.vote_type = 1 THEN
      v_up_delta := v_up_delta + 1;
    ELSE
      v_down_delta := v_down_delta + 1;
    END IF;
  END IF;

  INSERT INTO notifications (user_id, post_id, thread_id, upvotes, downvotes)
  VALUES (
    v_post_author_id,
    NEW.post_id,
    v_thread_id,
    GREATEST(v_up_delta, 0),
    GREATEST(v_down_delta, 0)
  )
  ON CONFLICT (user_id, post_id)
  DO UPDATE SET
    upvotes = GREATEST(notifications.upvotes + v_up_delta, 0),
    downvotes = GREATEST(notifications.downvotes + v_down_delta, 0),
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger: notify on vote delete (incremental)
CREATE OR REPLACE FUNCTION notify_on_vote_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_post_author_id UUID;
  v_down_delta INTEGER := 0;
  v_up_delta INTEGER := 0;
BEGIN
  SELECT author_id INTO v_post_author_id
  FROM forum_posts WHERE id = OLD.post_id;

  IF v_post_author_id IS NULL OR v_post_author_id = OLD.user_id THEN
    RETURN OLD;
  END IF;

  IF OLD.vote_type = 1 THEN
    v_up_delta := -1;
  ELSE
    v_down_delta := -1;
  END IF;

  UPDATE notifications
  SET upvotes = GREATEST(upvotes + v_up_delta, 0),
      downvotes = GREATEST(downvotes + v_down_delta, 0),
      updated_at = NOW()
  WHERE user_id = v_post_author_id AND post_id = OLD.post_id;

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_notify_on_vote_insert ON post_votes;
CREATE TRIGGER trigger_notify_on_vote_insert
  AFTER INSERT ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_vote_change();

DROP TRIGGER IF EXISTS trigger_notify_on_vote_update ON post_votes;
CREATE TRIGGER trigger_notify_on_vote_update
  AFTER UPDATE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_vote_change();

DROP TRIGGER IF EXISTS trigger_notify_on_vote_delete ON post_votes;
CREATE TRIGGER trigger_notify_on_vote_delete
  AFTER DELETE ON post_votes
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_vote_delete();

-- Get notification count (only counts notifications with new activity)
-- Note: Uses "greater than baseline" comparison, meaning notifications only show when
-- totals EXCEED what user last saw. If votes decrease then increase back, user won't
-- see notification until total exceeds their last-seen value. This is intentional -
-- user cares about "more popular than before" not "any interaction happened".
CREATE OR REPLACE FUNCTION get_notification_count()
RETURNS BIGINT
LANGUAGE sql SECURITY DEFINER SET search_path = public
STABLE
AS $$
  SELECT COUNT(*) FROM notifications
  WHERE user_id = auth.uid()
    AND (
      reply_count > baseline_reply_count OR
      upvotes > baseline_upvotes OR
      downvotes > baseline_downvotes
    );
$$;

-- Get notifications with full post data for PostCard display
-- Returns delta counts (current - baseline) as "new" activity counts
-- Only returns notifications where there's new activity (any delta > 0)
DROP FUNCTION IF EXISTS get_notifications(integer, integer);
CREATE OR REPLACE FUNCTION get_notifications(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id INTEGER,
  post_id INTEGER,
  thread_id INTEGER,
  thread_title TEXT,
  post_content TEXT,
  post_parent_id INTEGER,
  post_author_id UUID,
  post_author_name TEXT,
  post_author_avatar TEXT,
  post_author_avatar_path TEXT,
  post_created_at TIMESTAMPTZ,
  post_likes BIGINT,
  post_dislikes BIGINT,
  post_reply_count BIGINT,
  new_reply_count INTEGER,
  new_upvotes INTEGER,
  new_downvotes INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  -- Count only notifications with new activity
  SELECT COUNT(*) INTO v_total
  FROM notifications n
  WHERE n.user_id = auth.uid()
    AND (
      n.reply_count > n.baseline_reply_count OR
      n.upvotes > n.baseline_upvotes OR
      n.downvotes > n.baseline_downvotes
    );

  RETURN QUERY
  SELECT
    n.id,
    n.post_id,
    n.thread_id,
    t.title,
    p.content,
    p.parent_id,
    p.author_id,
    u.username,
    u.avatar_url,
    u.avatar_path,
    p.created_at,
    COALESCE(p.likes, 0),
    COALESCE(p.dislikes, 0),
    (SELECT COUNT(*) FROM forum_posts r WHERE r.parent_id = p.id AND COALESCE(r.is_deleted, FALSE) = FALSE),
    -- Delta counts (new activity since last dismissal)
    (n.reply_count - n.baseline_reply_count)::INTEGER,
    (n.upvotes - n.baseline_upvotes)::INTEGER,
    (n.downvotes - n.baseline_downvotes)::INTEGER,
    n.created_at,
    n.updated_at,
    v_total
  FROM notifications n
  JOIN forum_posts p ON p.id = n.post_id
  JOIN forum_threads t ON t.id = n.thread_id
  JOIN user_profiles u ON u.id = p.author_id
  WHERE n.user_id = auth.uid()
    AND (
      n.reply_count > n.baseline_reply_count OR
      n.upvotes > n.baseline_upvotes OR
      n.downvotes > n.baseline_downvotes
    )
  ORDER BY n.updated_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Dismiss a single notification (sets baseline = current, so "new" counts become 0)
CREATE OR REPLACE FUNCTION dismiss_notification(p_notification_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE notifications
  SET
    baseline_reply_count = reply_count,
    baseline_upvotes = upvotes,
    baseline_downvotes = downvotes
  WHERE id = p_notification_id AND user_id = auth.uid();
  RETURN FOUND;
END;
$$;

-- Dismiss all notifications (sets baseline = current for all)
CREATE OR REPLACE FUNCTION dismiss_all_notifications()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE notifications
  SET
    baseline_reply_count = reply_count,
    baseline_upvotes = upvotes,
    baseline_downvotes = downvotes
  WHERE user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
