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

-- Indexes (skip if already present)
CREATE INDEX IF NOT EXISTS idx_forum_threads_title_trgm ON forum_threads USING GIN (LOWER(title) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_posts_content_trgm ON forum_posts USING GIN (LOWER(content) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_parent_created ON forum_posts(thread_id, parent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_thread_op ON forum_posts(thread_id) WHERE parent_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_post_votes_post_type ON post_votes(post_id, vote_type);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_created ON bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_unread ON feedback_messages(recipient_id, user_id, created_at DESC) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_feedback_messages_recipient_unread ON feedback_messages(recipient_id) WHERE is_read = FALSE;

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
