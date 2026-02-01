-- Migration: 20260201_001_live_reply_counts
-- Description: Use live visible-reply counts in forum RPCs instead of stale reply_count column.
-- Author: Codex
-- Date: 2026-02-01

-- =============================================================================
-- UP MIGRATION
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_bookmarked_posts(p_user_id uuid, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_search_text text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
      count_visible_replies(p.id, v_is_admin) AS reply_count,
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

CREATE OR REPLACE FUNCTION public.get_paginated_forum_threads(p_category_ids integer[] DEFAULT NULL::integer[], p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort_by text DEFAULT 'recent'::text, p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false, p_public_only boolean DEFAULT false) RETURNS TABLE(id integer, title text, author_id uuid, author_name text, author_avatar text, author_avatar_path text, created_at timestamp with time zone, first_post_content text, reply_count bigint, total_likes bigint, total_dislikes bigint, has_poll boolean, is_op_deleted boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
  v_flagged_only BOOLEAN;
  v_deleted_only BOOLEAN;
BEGIN
  v_is_admin := public.check_is_admin();
  v_flagged_only := COALESCE(p_flagged_only, FALSE);
  v_deleted_only := COALESCE(p_deleted_only, FALSE);

  IF p_public_only THEN
    v_is_admin := FALSE;
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM forum_threads t
  JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
  JOIN user_profiles u ON u.id = t.author_id
  WHERE (p_category_ids IS NULL OR t.category_id = ANY(p_category_ids))
    AND (p_author_username IS NULL OR LOWER(u.username) = LOWER(p_author_username))
    AND (p_search_text IS NULL OR t.search_document @@ websearch_to_tsquery('simple', p_search_text))
    AND (NOT v_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
    AND (NOT v_deleted_only OR op.is_deleted = TRUE)
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
      count_visible_thread_replies(t.id, v_is_admin)::BIGINT AS reply_count,
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
      AND (NOT v_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
      AND (NOT v_deleted_only OR op.is_deleted = TRUE)
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

CREATE OR REPLACE FUNCTION public.get_paginated_thread_posts(p_thread_id integer, p_parent_id integer DEFAULT NULL::integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE user_profiles.id = auth.uid();
  v_is_admin := COALESCE(v_is_admin, FALSE);

  -- Count total posts
  SELECT COUNT(*) INTO v_total
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id
    AND (p_parent_id IS NULL AND p.parent_id IS NULL OR p.parent_id = p_parent_id)
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);

  RETURN QUERY
  SELECT
    p.id,
    p.thread_id,
    p.parent_id,
    p.author_id,
    u.username,
    u.avatar_url,
    p.content,
    p.additional_comments,
    p.created_at,
    p.edited_at,
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = p.id),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = p.id),
    (SELECT pv.vote_type FROM post_votes pv WHERE pv.post_id = p.id AND pv.user_id = auth.uid()),
    count_visible_replies(p.id, v_is_admin),
    p.is_flagged,
    p.flag_reason,
    COALESCE(p.is_deleted, FALSE),
    p.deleted_by,
    COALESCE(u.is_deleted, FALSE),
    v_total
  FROM forum_posts p
  JOIN user_profiles u ON u.id = p.author_id
  WHERE p.thread_id = p_thread_id
    AND (p_parent_id IS NULL AND p.parent_id IS NULL OR p.parent_id = p_parent_id)
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
  ORDER BY p.created_at ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_paginated_thread_posts(p_thread_id integer, p_parent_id integer DEFAULT NULL::integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort text DEFAULT 'popular'::text) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
      count_visible_replies(p.id, v_is_admin) AS reply_count,
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

CREATE OR REPLACE FUNCTION public.get_post_by_id(p_post_id integer) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
    count_visible_replies(p.id, v_is_admin),
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

CREATE OR REPLACE FUNCTION public.get_posts_by_author(p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
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
    AND (p_search_text IS NULL OR text_contains_all_words(p.content || ' ' || t.title, p_search_text))
    AND (NOT p_flagged_only OR p.is_flagged = TRUE)
    AND (NOT p_deleted_only OR COALESCE(p.is_deleted, FALSE) = TRUE)
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);

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
      p.created_at,
      (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = p.id) AS likes,
      (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = p.id) AS dislikes,
      count_visible_replies(p.id, v_is_admin) AS reply_count,
      COALESCE(p.is_deleted, FALSE) AS is_deleted,
      p.deleted_by,
      p.is_flagged,
      (p.parent_id IS NULL) AS is_thread_op
    FROM forum_posts p
    JOIN forum_threads t ON t.id = p.thread_id
    JOIN user_profiles u ON u.id = p.author_id
    WHERE (v_author_id IS NULL OR p.author_id = v_author_id)
      AND (p_search_text IS NULL OR text_contains_all_words(p.content || ' ' || t.title, p_search_text))
      AND (NOT p_flagged_only OR p.is_flagged = TRUE)
      AND (NOT p_deleted_only OR COALESCE(p.is_deleted, FALSE) = TRUE)
      AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE)
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

CREATE OR REPLACE FUNCTION public.get_posts_by_author(p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false, p_post_type text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
      count_visible_replies(p.id, v_is_admin) AS reply_count,
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

CREATE OR REPLACE FUNCTION public.get_thread_view(p_thread_id integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort text DEFAULT 'popular'::text) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, is_op boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_op_id INTEGER;
  v_total BIGINT;
BEGIN
  v_is_admin := public.check_is_admin();

  SELECT p.id INTO v_op_id
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id AND p.parent_id IS NULL
  LIMIT 1;

  IF v_op_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM forum_posts p
  WHERE p.thread_id = p_thread_id
    AND p.parent_id = v_op_id
    AND (v_is_admin OR COALESCE(p.is_deleted, FALSE) = FALSE);

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
    pv.vote_type AS user_vote,
    count_visible_replies(p.id, v_is_admin) AS reply_count,
    p.is_flagged,
    p.flag_reason,
    COALESCE(p.is_deleted, FALSE) AS is_deleted,
    p.deleted_by,
    COALESCE(u.is_deleted, FALSE) AS is_author_deleted,
    TRUE AS is_op,
    v_total AS total_count
  FROM forum_posts p
  JOIN user_profiles u ON u.id = p.author_id
  LEFT JOIN post_votes pv ON pv.post_id = p.id AND pv.user_id = auth.uid()
  WHERE p.id = v_op_id;

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
      pv.vote_type AS user_vote,
      count_visible_replies(p.id, v_is_admin) AS reply_count,
      p.is_flagged,
      p.flag_reason,
      COALESCE(p.is_deleted, FALSE) AS is_deleted,
      p.deleted_by,
      COALESCE(u.is_deleted, FALSE) AS is_author_deleted,
      FALSE AS is_op,
      v_total AS total_count
    FROM forum_posts p
    JOIN user_profiles u ON u.id = p.author_id
    LEFT JOIN post_votes pv ON pv.post_id = p.id AND pv.user_id = auth.uid()
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

-- =============================================================================
-- DOWN MIGRATION (for rollback - keep commented)
-- =============================================================================
-- Recreate functions with reply_count from the column (not live counts).
