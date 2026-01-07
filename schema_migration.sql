-- =============================================================================
-- PANDA FORUM - Schema Migration
-- =============================================================================
-- This file contains incremental updates to keep the database aligned with
-- schema.sql. Apply in Supabase SQL editor.
-- =============================================================================

-- =============================================================================
-- Server-side moderation helpers
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_flag_reasons(p_content TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
STABLE
AS $$
DECLARE
  v_patterns TEXT[];
  v_reasons TEXT[];
  v_context_words TEXT[];
  v_has_context BOOLEAN := FALSE;
  v_pattern TEXT;
  v_reason TEXT;
  v_match TEXT;
  v_result TEXT[] := ARRAY[]::TEXT[];
  i INTEGER;
BEGIN
  IF p_content IS NULL OR length(p_content) = 0 THEN
    RETURN v_result;
  END IF;

  v_patterns := ARRAY[
    '(?i)\\y(f+u+c+k+|f+[*@#$%]ck|fuk|fck)\\y',
    '(?i)\\y(s+h+i+t+|sh[*@#$%]t|sht)\\y',
    '(?i)\\y(a+s+s+h+o+l+e+|a+s+s+)\\y',
    '(?i)\\y(b+i+t+c+h+|b[*@#$%]tch)\\y',
    '(?i)\\y(d+a+m+n+)\\y',
    '(?i)\\y(c+u+n+t+)\\y',
    '(?i)\\y(d+i+c+k+|d[*@#$%]ck)\\y',
    '(?i)\\y(p+u+s+s+y+)\\y',
    '(?i)\\y(c+o+c+k+)\\y',
    '(?i)\\y(w+h+o+r+e+)\\y',
    '(?i)\\y(s+l+u+t+)\\y',
    '(?i)\\y(n+[i1]+g+[g4]+[e3a]+r*|n[*@#$%]gg[*@#$%]r)\\y',
    '(?i)\\y(f+[a4]+g+[o0]+t*|f[*@#$%]gg[*@#$%]t)\\y',
    '(?i)\\y(r+[e3]+t+[a4]+r+d+)\\y',
    '(?i)\\y(kill\\s+(you|yourself|him|her|them))\\y',
    '(?i)\\y(i(''ll|will)\\s+murder)\\y',
    '(?i)\\y(death\\s+threat)\\y',
    '(?i)\\y(buy\\s+now|click\\s+here|free\\s+money)\\y',
    '(?i)(https?://[^\\s]+){3,}'
  ];

  v_reasons := ARRAY[
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Inappropriate language',
    'Potential threat/violence',
    'Potential threat/violence',
    'Potential threat/violence',
    'Potential spam',
    'Potential spam'
  ];

  v_context_words := ARRAY[
    'assessment',
    'class',
    'assume',
    'bass',
    'pass',
    'mass',
    'assistance',
    'associate',
    'assassin',
    'cockpit',
    'cocktail',
    'peacock',
    'hancock',
    'scunthorpe',
    'dickens',
    'dickerson'
  ];

  v_has_context := EXISTS (
    SELECT 1 FROM unnest(v_context_words) AS w
    WHERE p_content ILIKE '%' || w || '%'
  );

  FOR i IN 1..array_length(v_patterns, 1) LOOP
    v_pattern := v_patterns[i];
    v_reason := v_reasons[i];
    v_match := substring(p_content from v_pattern);

    IF v_match IS NULL THEN
      CONTINUE;
    END IF;

    IF v_has_context THEN
      IF EXISTS (
        SELECT 1 FROM unnest(v_context_words) AS w
        WHERE position(lower(w) in lower(v_match)) > 0
           OR position(lower(v_match) in lower(w)) > 0
      ) THEN
        CONTINUE;
      END IF;
    END IF;

    IF NOT (v_reason = ANY(v_result)) THEN
      v_result := array_append(v_result, v_reason);
    END IF;
  END LOOP;

  IF p_content ~ '[A-Z\\s!]{50,}' THEN
    IF NOT ('Excessive caps' = ANY(v_result)) THEN
      v_result := array_append(v_result, 'Excessive caps');
    END IF;
  END IF;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_thread_flag_reasons(p_title TEXT, p_content TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
STABLE
AS $$
DECLARE
  v_title_reasons TEXT[] := public.get_flag_reasons(p_title);
  v_content_reasons TEXT[] := public.get_flag_reasons(p_content);
  v_combined TEXT[];
BEGIN
  v_combined := array(
    SELECT DISTINCT unnest(
      COALESCE(v_title_reasons, ARRAY[]::TEXT[])
      || COALESCE(v_content_reasons, ARRAY[]::TEXT[])
    )
  );

  RETURN COALESCE(v_combined, ARRAY[]::TEXT[]);
END;
$$;

-- =============================================================================
-- Hardened profile creation (auth + reserved username checks)
-- =============================================================================
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
  v_attempts INTEGER := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = p_user_id) THEN
    SELECT up.username INTO v_final_username FROM user_profiles up WHERE up.id = p_user_id;
    RETURN QUERY SELECT TRUE, v_final_username, 'Profile already exists'::TEXT;
    RETURN;
  END IF;

  v_final_username := COALESCE(p_username, 'Panda' || lpad(floor(random() * 10000)::text, 4, '0'));

  IF p_username IS NOT NULL THEN
    IF NOT public.is_username_available(v_final_username) THEN
      RAISE EXCEPTION 'Username not available';
    END IF;
  ELSE
    WHILE NOT public.is_username_available(v_final_username) LOOP
      v_attempts := v_attempts + 1;
      IF v_attempts > 10 THEN
        RAISE EXCEPTION 'Failed to generate a unique username';
      END IF;
      v_final_username := 'Panda' || lpad(floor(random() * 10000)::text, 4, '0');
    END LOOP;
  END IF;

  INSERT INTO user_profiles (id, username, role, avatar_path)
  VALUES (p_user_id, v_final_username, 'user', p_avatar_path);

  INSERT INTO user_stats (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

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

REVOKE EXECUTE ON FUNCTION create_user_profile(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_user_profile(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- Server-side moderation enforcement
-- =============================================================================
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
  v_flag_reasons TEXT[];
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_flag_reasons := public.get_thread_flag_reasons(p_title, p_content);

  INSERT INTO forum_threads (title, category_id, author_id, is_flagged, flag_reason)
  VALUES (
    p_title,
    p_category_id,
    auth.uid(),
    array_length(v_flag_reasons, 1) > 0,
    CASE
      WHEN array_length(v_flag_reasons, 1) > 0 THEN array_to_string(v_flag_reasons, ', ')
      ELSE NULL
    END
  )
  RETURNING id INTO v_thread_id;

  INSERT INTO forum_posts (thread_id, author_id, content, is_flagged, flag_reason)
  VALUES (
    v_thread_id,
    auth.uid(),
    p_content,
    array_length(v_flag_reasons, 1) > 0,
    CASE
      WHEN array_length(v_flag_reasons, 1) > 0 THEN array_to_string(v_flag_reasons, ', ')
      ELSE NULL
    END
  )
  RETURNING id INTO v_post_id;

  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_thread_id;
END;
$$;

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
  v_flag_reasons TEXT[];
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_flag_reasons := public.get_flag_reasons(p_content);

  INSERT INTO forum_posts (thread_id, parent_id, author_id, content, is_flagged, flag_reason)
  VALUES (
    p_thread_id,
    p_parent_id,
    auth.uid(),
    p_content,
    array_length(v_flag_reasons, 1) > 0,
    CASE
      WHEN array_length(v_flag_reasons, 1) > 0 THEN array_to_string(v_flag_reasons, ', ')
      ELSE NULL
    END
  )
  RETURNING id INTO v_post_id;

  INSERT INTO post_votes (post_id, user_id, vote_type)
  VALUES (v_post_id, auth.uid(), 1);

  RETURN v_post_id;
END;
$$;

-- =============================================================================
-- Public-only guard for thread listings
-- =============================================================================
CREATE OR REPLACE FUNCTION get_paginated_forum_threads(
  p_category_ids INTEGER[] DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_sort_by TEXT DEFAULT 'recent',
  p_author_username TEXT DEFAULT NULL,
  p_search_text TEXT DEFAULT NULL,
  p_flagged_only BOOLEAN DEFAULT FALSE,
  p_deleted_only BOOLEAN DEFAULT FALSE,
  p_public_only BOOLEAN DEFAULT FALSE
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
  v_flagged_only BOOLEAN := p_flagged_only;
  v_deleted_only BOOLEAN := p_deleted_only;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_not_blocked() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_is_admin := public.check_is_admin();
  IF p_public_only OR NOT v_is_admin THEN
    v_flagged_only := FALSE;
    v_deleted_only := FALSE;
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

-- =============================================================================
-- Optimize get_thread_view + make vote_post atomic
-- =============================================================================
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

  SELECT vote_type INTO v_existing_vote
  FROM post_votes
  WHERE post_id = p_post_id AND user_id = auth.uid()
  FOR UPDATE;

  IF p_vote_type = 0 THEN
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSIF v_existing_vote = p_vote_type THEN
    DELETE FROM post_votes WHERE post_id = p_post_id AND user_id = auth.uid();
  ELSE
    INSERT INTO post_votes (post_id, user_id, vote_type)
    VALUES (p_post_id, auth.uid(), p_vote_type)
    ON CONFLICT (post_id, user_id) DO UPDATE SET vote_type = EXCLUDED.vote_type;
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
-- Privacy-aware public profile lookup
-- =============================================================================
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
  SELECT
    up.id,
    CASE
      WHEN COALESCE(up.is_private, FALSE)
        AND auth.uid() IS DISTINCT FROM up.id
        AND NOT public.check_is_admin()
      THEN NULL
      ELSE up.username
    END AS username,
    CASE
      WHEN COALESCE(up.is_private, FALSE)
        AND auth.uid() IS DISTINCT FROM up.id
        AND NOT public.check_is_admin()
      THEN NULL
      ELSE up.avatar_url
    END AS avatar_url,
    CASE
      WHEN COALESCE(up.is_private, FALSE)
        AND auth.uid() IS DISTINCT FROM up.id
        AND NOT public.check_is_admin()
      THEN NULL
      ELSE up.avatar_path
    END AS avatar_path,
    COALESCE(up.is_private, FALSE) AS is_private
  FROM user_profiles up
  WHERE up.id = p_user_id;
$$;

-- Internal profile lookup for cache (auth required, admin or self)
CREATE OR REPLACE FUNCTION get_user_profile_cache(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  role TEXT,
  is_blocked BOOLEAN,
  username TEXT,
  avatar_url TEXT,
  avatar_path TEXT,
  is_private BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_is_admin := public.check_is_admin();
  IF NOT v_is_admin AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN QUERY
  SELECT
    up.id,
    up.role,
    up.is_blocked,
    up.username,
    up.avatar_url,
    up.avatar_path,
    up.is_private
  FROM user_profiles up
  WHERE up.id = p_user_id;
END;
$$;

-- =============================================================================
-- Simplify admin RLS checks to use check_is_admin()
-- =============================================================================
DROP POLICY IF EXISTS "Anyone can view non-deleted posts" ON forum_posts;
CREATE POLICY "Anyone can view non-deleted posts" ON forum_posts
  FOR SELECT USING (
    COALESCE(is_deleted, FALSE) = FALSE
    OR public.check_is_admin()
  );

DROP POLICY IF EXISTS "Admins can view votes" ON post_votes;
CREATE POLICY "Admins can view votes" ON post_votes
  FOR SELECT USING (
    public.check_is_admin()
  );

-- =============================================================================
-- RPC EXECUTE PERMISSIONS (explicit allowlist)
-- =============================================================================
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

GRANT EXECUTE ON FUNCTION get_public_user_profile(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_public_user_stats(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_paginated_forum_threads(INTEGER[], INTEGER, INTEGER, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION get_thread_view(INTEGER, INTEGER, INTEGER, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_post_by_id(INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_paginated_thread_posts(INTEGER, INTEGER, INTEGER, INTEGER, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_poll_data(INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION public.get_placement_filters() TO anon;
GRANT EXECUTE ON FUNCTION public.search_placements(TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION public.reverse_search_placements(TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION public.get_programs_for_university(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_universities_for_program(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_user_profile_cache(UUID) TO authenticated;

-- =============================================================================
-- Enforce lowercase university names in pt_university
-- =============================================================================

-- 1. Convert existing university names to lowercase
UPDATE pt_university SET university = LOWER(university);

-- 2. Create trigger function to enforce lowercase and normalize whitespace
CREATE OR REPLACE FUNCTION enforce_lowercase_university()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Lowercase, trim, and collapse multiple spaces to single space
  NEW.university := LOWER(TRIM(REGEXP_REPLACE(NEW.university, '\s+', ' ', 'g')));
  RETURN NEW;
END;
$$;

-- 3. Create trigger on pt_university table
DROP TRIGGER IF EXISTS enforce_lowercase_university_trigger ON pt_university;
CREATE TRIGGER enforce_lowercase_university_trigger
  BEFORE INSERT OR UPDATE ON pt_university
  FOR EACH ROW
  EXECUTE FUNCTION enforce_lowercase_university();

-- 4. Add unique constraint on lowercase university name to prevent duplicates
-- First, remove any duplicates (keep the one with lowest id)
DELETE FROM pt_university a
USING pt_university b
WHERE a.id > b.id
  AND LOWER(a.university) = LOWER(b.university);

-- Then add unique index on lowercase university
DROP INDEX IF EXISTS idx_pt_university_name_unique;
CREATE UNIQUE INDEX idx_pt_university_name_unique ON pt_university (LOWER(university));
