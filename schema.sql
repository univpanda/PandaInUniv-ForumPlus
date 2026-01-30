-- =============================================================================
-- PandaInUniv Forum Plus Database Schema
-- =============================================================================
-- Version: 1.0.0
-- Generated: 2025-01-24
-- Last Updated: 2025-01-30
--
-- This schema file contains the complete database structure including:
-- - Custom types (enums)
-- - Tables with constraints
-- - Indexes
-- - Functions
-- - Triggers
-- - Row Level Security (RLS) policies
--
-- =============================================================================
-- VERSIONING & MIGRATIONS
-- =============================================================================
--
-- This file represents the FULL schema for fresh database creation.
-- For incremental updates to existing databases, use migration files in:
--   /migrations/YYYYMMDD_NNN_description.sql
--
-- Migration file naming convention:
--   YYYYMMDD_NNN_description.sql
--   Example: 20250130_001_add_avatar_path_column.sql
--
-- Each migration should:
--   1. Be idempotent (safe to run multiple times)
--   2. Include both UP and DOWN sections (commented)
--   3. Update the schema_version table
--
-- =============================================================================
-- PREREQUISITES
-- =============================================================================
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- (auth.users table must exist for foreign key references)
--
-- =============================================================================
-- CHANGELOG
-- =============================================================================
-- v1.0.0 (2025-01-30) - Initial versioned schema
--   - Added schema_version table for tracking migrations
--   - Added version header and migration documentation
--
-- =============================================================================

-- Schema version tracking table (created first)
CREATE TABLE IF NOT EXISTS public.schema_version (
    version VARCHAR(20) PRIMARY KEY,
    description TEXT,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    applied_by TEXT DEFAULT current_user
);

-- Record current schema version
INSERT INTO public.schema_version (version, description)
VALUES ('1.0.0', 'Initial versioned schema')
ON CONFLICT (version) DO NOTHING;

-- =============================================================================
-- SCHEMA DEFINITIONS BEGIN
-- =============================================================================

-- Name: school_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.school_type AS ENUM (
    'degree_granting',
    'continuing_education',
    'non_degree',
    'administrative'
);


--
-- Name: add_reply(integer, text, integer, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_reply(p_thread_id integer, p_content text, p_parent_id integer DEFAULT NULL::integer, p_is_flagged boolean DEFAULT false, p_flag_reason text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: apply_user_stats_delta(uuid, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_user_stats_delta(p_user_id uuid, p_thread_delta bigint DEFAULT 0, p_post_delta bigint DEFAULT 0, p_deleted_delta bigint DEFAULT 0, p_flagged_delta bigint DEFAULT 0, p_upvotes_received_delta bigint DEFAULT 0, p_downvotes_received_delta bigint DEFAULT 0, p_upvotes_given_delta bigint DEFAULT 0, p_downvotes_given_delta bigint DEFAULT 0) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: check_is_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_is_admin(p_user_id uuid DEFAULT auth.uid()) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE((SELECT role = 'admin' FROM public.user_profiles WHERE id = p_user_id), FALSE);
$$;


--
-- Name: check_username_privacy(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_username_privacy(p_username text) RETURNS TABLE(user_exists boolean, is_private boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user user_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM user_profiles WHERE LOWER(username) = LOWER(p_username);

  IF v_user IS NULL THEN
    RETURN QUERY SELECT FALSE, FALSE;
  ELSE
    RETURN QUERY SELECT TRUE, COALESCE(v_user.is_private, FALSE);
  END IF;
END;
$$;


--
-- Name: create_poll_thread(text, text, text[], boolean, integer, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_poll_thread(p_title text, p_content text, p_poll_options text[], p_allow_multiple boolean DEFAULT false, p_duration_hours integer DEFAULT 0, p_is_flagged boolean DEFAULT false, p_flag_reason text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: create_poll_thread(text, text, text[], boolean, boolean, boolean, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_poll_thread(p_title text, p_content text, p_poll_options text[], p_allow_multiple boolean DEFAULT false, p_show_results_before_vote boolean DEFAULT false, p_allow_vote_change boolean DEFAULT true, p_is_flagged boolean DEFAULT false, p_flag_reason text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_thread_id INTEGER;
  v_poll_id INTEGER;
  v_option TEXT;
  v_order INTEGER := 0;
BEGIN
  -- Create thread
  v_thread_id := create_thread(p_title, NULL, p_content, p_is_flagged, p_flag_reason);

  -- Create poll
  INSERT INTO polls (thread_id, allow_multiple, allow_vote_change, show_results_before_vote)
  VALUES (v_thread_id, p_allow_multiple, p_allow_vote_change, p_show_results_before_vote)
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


--
-- Name: create_thread(text, integer, text, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_thread(p_title text, p_category_id integer, p_content text, p_is_flagged boolean DEFAULT false, p_flag_reason text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: create_user_profile(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user_profile(p_user_id uuid, p_email text) RETURNS TABLE(success boolean, username text, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE
  v_final_username TEXT;
  v_attempts INT := 0;
  v_pandakeeper_id UUID;
  v_welcome_message TEXT;
BEGIN
  -- Check if profile already exists
  IF EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = p_user_id) THEN
    SELECT up.username INTO v_final_username FROM user_profiles up WHERE up.id = p_user_id;
    RETURN QUERY SELECT TRUE, v_final_username, 'Profile already exists'::TEXT;
    RETURN;
  END IF;

  -- Generate unique panda username (80 adj × 60 nouns × 10000 = 48M combinations)
  LOOP
    v_final_username := generate_panda_username();
    v_attempts := v_attempts + 1;

    EXIT WHEN NOT EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = LOWER(v_final_username));
    EXIT WHEN v_attempts >= 5; -- Safety limit
  END LOOP;

  -- Fallback: append UUID fragment if still colliding
  IF EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = LOWER(v_final_username)) THEN
    v_final_username := v_final_username || substr(p_user_id::text, 1, 4);
  END IF;

  -- Insert the new user profile
  INSERT INTO user_profiles (id, username, role, avatar_index)
  VALUES (p_user_id, v_final_username, 'user', floor(random() * 6)::integer);

  -- Send welcome message from PandaKeeper
  SELECT up.id INTO v_pandakeeper_id FROM user_profiles up WHERE up.username = 'PandaKeeper' LIMIT 1;

  IF v_pandakeeper_id IS NOT NULL THEN
    v_welcome_message := 'Hello Panda ' || v_final_username || '!

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
END;$$;


--
-- Name: create_user_profile(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user_profile(p_user_id uuid, p_email text, p_username text DEFAULT NULL::text, p_avatar_path text DEFAULT NULL::text) RETURNS TABLE(success boolean, username text, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: delete_own_account(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_own_account() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  PERFORM delete_user_account(auth.uid());
END;
$$;


--
-- Name: delete_post(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_post(p_post_id integer) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: delete_user_account(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user_account(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_timestamp TEXT;
  v_current_email TEXT;
  v_is_admin BOOLEAN;
  v_current_user_id UUID;
BEGIN
  v_current_user_id := auth.uid();

  -- Check permission: must be own account OR admin
  IF p_user_id <> v_current_user_id THEN
    SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE id = v_current_user_id;
    IF NOT COALESCE(v_is_admin, FALSE) THEN
      RAISE EXCEPTION 'Permission denied: can only delete your own account';
    END IF;
  END IF;

  v_timestamp := TO_CHAR(NOW(), 'YYYYMMDDHH24MISS');

  -- Get current email from auth.users
  SELECT email INTO v_current_email FROM auth.users WHERE id = p_user_id;

  IF v_current_email IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Mark profile as deleted (keeps username for post attribution)
  UPDATE user_profiles SET is_deleted = TRUE WHERE id = p_user_id;

  -- Delete OAuth identities to allow re-registration with same provider
  DELETE FROM auth.identities WHERE user_id = p_user_id;

  -- Modify email in auth.users to allow re-registration with same email
  UPDATE auth.users SET email = v_current_email || '_deleted_' || v_timestamp WHERE id = p_user_id;
END;
$$;


--
-- Name: dismiss_all_notifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dismiss_all_notifications() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: dismiss_notification(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dismiss_notification(p_notification_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: edit_post(integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.edit_post(p_post_id integer, p_content text DEFAULT NULL::text, p_additional_comments text DEFAULT NULL::text) RETURNS TABLE(success boolean, can_edit_content boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: enforce_lowercase_country(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_country() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.name := LOWER(TRIM(REGEXP_REPLACE(NEW.name, '\s+', ' ', 'g')));
  NEW.code := UPPER(TRIM(NEW.code));
  RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_department(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_department() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.department := LOWER(TRIM(REGEXP_REPLACE(NEW.department, '\s+', ' ', 'g')));
  RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_field(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_field() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.field IS NOT NULL THEN
    NEW.field := LOWER(NEW.field);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_institution(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_institution() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.type := LOWER(NEW.type);
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_pt_faculty(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_pt_faculty() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.name = LOWER(NEW.name);
    NEW.profile_url = LOWER(NEW.profile_url);
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_pt_faculty_education(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_pt_faculty_education() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Lowercase and trim
    NEW.degree := LOWER(TRIM(NEW.degree));
    
    -- Normalize common variations
    NEW.degree := CASE NEW.degree
        WHEN 'ph.d.' THEN 'phd'
        WHEN 'ph.d' THEN 'phd'
        WHEN 'b.a.' THEN 'ba'
        WHEN 'a.b.' THEN 'ba'
        WHEN 'b.s.' THEN 'bs'
        WHEN 'm.a.' THEN 'ma'
        WHEN 'm.s.' THEN 'ms'
        WHEN 'm.b.a.' THEN 'mba'
        WHEN 'j.d.' THEN 'jd'
        WHEN 'm.f.a.' THEN 'mfa'
        WHEN 'b.f.a.' THEN 'bfa'
        WHEN 'm.arch.' THEN 'march'
        WHEN 'b.arch.' THEN 'barch'
        WHEN 'b.arch' THEN 'barch'
        WHEN 'l.l.m.' THEN 'llm'
        WHEN 'l.l.b.' THEN 'llb'
        WHEN 'm.sc.' THEN 'ms'
        WHEN 'b.sc.' THEN 'bs'
        ELSE NEW.degree
    END;
    
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_pt_people(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_pt_people() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.name := LOWER(NEW.name);
    NEW.initial_designation := LOWER(NEW.initial_designation);
    NEW.current_designation := LOWER(NEW.current_designation);
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_pt_people_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_pt_people_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.name := LOWER(NEW.name);
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_pt_placement(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_pt_placement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.name := LOWER(NEW.name);
    NEW.role := LOWER(NEW.role);
    NEW.placement_univ := LOWER(NEW.placement_univ);
    NEW.university := LOWER(NEW.university);
    NEW.degree := LOWER(NEW.degree);
    NEW.discipline := LOWER(NEW.discipline);
    NEW.program := LOWER(NEW.program);
    RETURN NEW;
END;
$$;


--
-- Name: enforce_lowercase_school(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_lowercase_school() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.school := LOWER(TRIM(REGEXP_REPLACE(NEW.school, '\s+', ' ', 'g'))); RETURN NEW; END; $$;


--
-- Name: ensure_user_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_user_stats() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO user_stats (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;


--
-- Name: generate_panda_username(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_panda_username() RETURNS text
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


--
-- Name: generate_unique_username(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_unique_username(base_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  clean_name TEXT;
  candidate TEXT;
  suffix INT := 0;
BEGIN
  -- Clean the base name: remove spaces, special chars, lowercase
  clean_name := lower(regexp_replace(COALESCE(base_name, 'user'), '[^a-zA-Z0-9]', '', 'g'));
  
  -- If empty after cleaning, use 'user'
  IF clean_name = '' THEN
    clean_name := 'user';
  END IF;
  
  -- Truncate to 20 chars to leave room for suffix
  clean_name := left(clean_name, 20);
  
  -- Try the clean name first
  candidate := clean_name;
  
  -- Keep trying with incrementing suffix until unique
  WHILE EXISTS (SELECT 1 FROM user_profiles WHERE lower(username) = lower(candidate)) LOOP
    suffix := suffix + 1;
    candidate := clean_name || suffix::text;
  END LOOP;
  
  RETURN candidate;
END;
$$;


--
-- Name: get_bookmarked_posts(uuid, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bookmarked_posts(p_user_id uuid, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_search_text text DEFAULT NULL::text) RETURNS json
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


--
-- Name: get_bookmarked_thread_ids(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bookmarked_thread_ids(p_user_id uuid) RETURNS SETOF integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_conversation_messages(uuid, uuid, integer, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_conversation_messages(p_user_id uuid, p_partner_id uuid, p_limit integer DEFAULT 50, p_before_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(id uuid, user_id uuid, recipient_id uuid, content text, is_read boolean, created_at timestamp with time zone, sender_username text, sender_avatar text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_flag_reasons(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_flag_reasons(p_content text) RETURNS text[]
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
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
$_$;


--
-- Name: get_flagged_posts(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_flagged_posts(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, thread_id integer, thread_title text, parent_id integer, content text, author_id uuid, author_name text, author_avatar text, author_avatar_path text, created_at timestamp with time zone, flag_reason text, is_thread_op boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_ignored_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_ignored_users() RETURNS TABLE(ignored_user_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY SELECT iu.ignored_user_id FROM ignored_users iu WHERE iu.user_id = auth.uid();
END;
$$;


--
-- Name: get_my_profile_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_profile_stats() RETURNS TABLE(thread_count bigint, post_count bigint, upvotes_received bigint, downvotes_received bigint, upvotes_given bigint, downvotes_given bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Count threads where OP is not deleted
    (SELECT COUNT(*) FROM forum_threads t
     JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
     WHERE t.author_id = auth.uid() AND COALESCE(op.is_deleted, false) = false),
    -- Count replies only (posts with parent_id, not thread OPs)
    (SELECT COUNT(*) FROM forum_posts
     WHERE author_id = auth.uid()
     AND parent_id IS NOT NULL
     AND COALESCE(is_deleted, false) = false),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0)
     FROM post_votes pv JOIN forum_posts fp ON pv.post_id = fp.id WHERE fp.author_id = auth.uid()),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0)
     FROM post_votes pv JOIN forum_posts fp ON pv.post_id = fp.id WHERE fp.author_id = auth.uid()),
    (SELECT COUNT(*) FROM post_votes WHERE user_id = auth.uid() AND vote_type = 1),
    (SELECT COUNT(*) FROM post_votes WHERE user_id = auth.uid() AND vote_type = -1);
END;
$$;


--
-- Name: get_my_profile_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_profile_status() RETURNS TABLE(role text, is_blocked boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT up.role, COALESCE(up.is_blocked, FALSE)
  FROM user_profiles up
  WHERE up.id = auth.uid();
$$;


--
-- Name: get_notification_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_notification_count() RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COUNT(*) FROM notifications
  WHERE user_id = auth.uid()
    AND (
      reply_count > baseline_reply_count OR
      upvotes > baseline_upvotes OR
      downvotes > baseline_downvotes
    );
$$;


--
-- Name: get_notifications(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_notifications(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, post_id integer, thread_id integer, thread_title text, post_content text, post_parent_id integer, post_author_id uuid, post_author_name text, post_author_avatar text, post_author_avatar_path text, post_created_at timestamp with time zone, post_likes bigint, post_dislikes bigint, post_reply_count bigint, new_reply_count integer, new_upvotes integer, new_downvotes integer, created_at timestamp with time zone, updated_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_paginated_forum_threads(integer[], integer, integer, text, text, text, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paginated_forum_threads(p_category_ids integer[] DEFAULT NULL::integer[], p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort_by text DEFAULT 'recent'::text, p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false, p_public_only boolean DEFAULT false) RETURNS TABLE(id integer, title text, author_id uuid, author_name text, author_avatar text, author_avatar_path text, created_at timestamp with time zone, first_post_content text, reply_count bigint, total_likes bigint, total_dislikes bigint, has_poll boolean, is_op_deleted boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_paginated_thread_posts(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paginated_thread_posts(p_thread_id integer, p_parent_id integer DEFAULT NULL::integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, total_count bigint)
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
    (SELECT COUNT(*) FROM forum_posts r WHERE r.parent_id = p.id),
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


--
-- Name: get_paginated_thread_posts(integer, integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paginated_thread_posts(p_thread_id integer, p_parent_id integer DEFAULT NULL::integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort text DEFAULT 'popular'::text) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, total_count bigint)
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


--
-- Name: get_paginated_threads(integer, integer, text, text, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paginated_threads(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort_by text DEFAULT 'recent'::text, p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false) RETURNS TABLE(id integer, title text, category_id integer, author_id uuid, author_name text, author_avatar text, created_at timestamp with time zone, op_content text, reply_count bigint, likes bigint, dislikes bigint, is_op_deleted boolean, is_flagged boolean, flag_reason text, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_total BIGINT;
  v_author_id UUID;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM user_profiles WHERE user_profiles.id = auth.uid();
  v_is_admin := COALESCE(v_is_admin, FALSE);

  -- Look up author ID if username filter provided
  IF p_author_username IS NOT NULL AND p_author_username != '' THEN
    SELECT user_profiles.id INTO v_author_id FROM user_profiles WHERE LOWER(username) = LOWER(p_author_username);
  END IF;

  -- Count total matching threads
  SELECT COUNT(*) INTO v_total
  FROM forum_threads t
  JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
  WHERE (v_author_id IS NULL OR t.author_id = v_author_id)
    AND (p_search_text IS NULL OR text_contains_all_words(t.title || ' ' || op.content, p_search_text))
    AND (NOT p_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
    AND (NOT p_deleted_only OR op.is_deleted = TRUE)
    AND (v_is_admin OR COALESCE(op.is_deleted, FALSE) = FALSE
         OR EXISTS (SELECT 1 FROM forum_posts r WHERE r.thread_id = t.id AND r.parent_id IS NOT NULL AND COALESCE(r.is_deleted, FALSE) = FALSE));

  RETURN QUERY
  SELECT
    t.id,
    t.title,
    t.category_id,
    t.author_id,
    u.username,
    u.avatar_url,
    -- For 'recent' sort, return last_activity; otherwise return thread creation time
    CASE WHEN p_sort_by = 'recent' THEN COALESCE(t.last_activity, t.created_at) ELSE t.created_at END,
    op.content,
    count_visible_thread_replies(t.id, v_is_admin),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = op.id),
    (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = op.id),
    COALESCE(op.is_deleted, FALSE),
    t.is_flagged,
    t.flag_reason,
    v_total
  FROM forum_threads t
  JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
  JOIN user_profiles u ON u.id = t.author_id
  WHERE (v_author_id IS NULL OR t.author_id = v_author_id)
    AND (p_search_text IS NULL OR text_contains_all_words(t.title || ' ' || op.content, p_search_text))
    AND (NOT p_flagged_only OR t.is_flagged = TRUE OR op.is_flagged = TRUE)
    AND (NOT p_deleted_only OR op.is_deleted = TRUE)
    AND (v_is_admin OR COALESCE(op.is_deleted, FALSE) = FALSE
         OR EXISTS (SELECT 1 FROM forum_posts r WHERE r.thread_id = t.id AND r.parent_id IS NOT NULL AND COALESCE(r.is_deleted, FALSE) = FALSE))
  ORDER BY
    -- Recent: sort by last activity (last reply or creation time)
    CASE WHEN p_sort_by = 'recent' THEN COALESCE(t.last_activity, t.created_at) END DESC,
    -- Popular: sort by OP likes, then reply count, then newest
    CASE WHEN p_sort_by = 'popular' THEN (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = op.id) END DESC,
    CASE WHEN p_sort_by = 'popular' THEN count_visible_thread_replies(t.id, v_is_admin) END DESC,
    -- New: sort by thread creation time (also fallback for all sorts)
    t.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


--
-- Name: get_placement_filters(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_placement_filters() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'degrees', json_build_array('PhD'),
    'programs', (
      SELECT json_agg(DISTINCT INITCAP(e.field) ORDER BY INITCAP(e.field))
      FROM pt_faculty_education e
      WHERE e.field IS NOT NULL AND e.field != '' AND LOWER(e.degree) = 'phd'
    ),
    'universities', (
      SELECT json_agg(DISTINCT INITCAP(i.english_name) ORDER BY INITCAP(i.english_name))
      FROM pt_faculty_education e
      JOIN pt_institute i ON e.institution_id = i.id
      WHERE LOWER(e.degree) = 'phd' AND i.english_name IS NOT NULL AND i.english_name != ''
    ),
    'years', (
      SELECT json_agg(DISTINCT c.year ORDER BY c.year DESC)
      FROM pt_faculty_career c
      JOIN pt_faculty_education e ON c.faculty_id = e.faculty_id AND LOWER(e.degree) = 'phd'
      WHERE c.year IS NOT NULL AND c.year >= COALESCE(e.year, 1900)
    )
  ) INTO result;

  RETURN result;
END;
$$;


--
-- Name: get_poll_data(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_poll_data(p_thread_id integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_post_by_id(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_post_by_id(p_post_id integer) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean)
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


--
-- Name: get_posts_by_author(text, text, integer, integer, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_posts_by_author(p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false) RETURNS json
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


--
-- Name: get_posts_by_author(text, text, integer, integer, boolean, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_posts_by_author(p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false, p_post_type text DEFAULT NULL::text) RETURNS json
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

  v_is_admin := public.check_is_admin(v_current_user_id);
  SELECT username INTO v_current_username
  FROM user_profiles WHERE id = v_current_user_id;

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


--
-- Name: get_programs_for_university(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_programs_for_university(p_university text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN (
    SELECT json_agg(DISTINCT INITCAP(e.field) ORDER BY INITCAP(e.field))
    FROM pt_faculty_education e
    JOIN pt_institute i ON e.institution_id = i.id
    WHERE LOWER(e.degree) = 'phd'
      AND LOWER(i.english_name) = LOWER(p_university)
      AND e.field IS NOT NULL
      AND e.field != ''
  );
END;
$$;


--
-- Name: get_programs_for_year_range(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_programs_for_year_range(p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer) RETURNS TABLE(program text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT INITCAP(e.field)
  FROM pt_faculty_education e
  JOIN pt_faculty_career c ON c.faculty_id = e.faculty_id
  WHERE LOWER(e.degree) = 'phd'
    AND e.field IS NOT NULL
    AND (c.designation IS NOT NULL OR c.institution_id IS NOT NULL)
    AND (p_from_year IS NULL OR e.year >= p_from_year)
    AND (p_to_year IS NULL OR e.year <= p_to_year)
  ORDER BY INITCAP(e.field);
END;
$$;


--
-- Name: get_programs_with_placements(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_programs_with_placements(p_university text, p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN (
    WITH phd_grads AS (
      SELECT
        e.faculty_id,
        e.field as program,
        e.year as phd_year
      FROM pt_faculty_education e
      JOIN pt_institute i ON e.institution_id = i.id
      WHERE LOWER(e.degree) = 'phd'
        AND LOWER(i.english_name) = LOWER(p_university)
    ),
    first_career AS (
      SELECT DISTINCT ON (c.faculty_id)
        c.faculty_id,
        c.year as placement_year
      FROM pt_faculty_career c
      JOIN phd_grads g ON c.faculty_id = g.faculty_id
      WHERE c.year >= COALESCE(g.phd_year, 1900)
        AND (c.institution_name IS NOT NULL OR c.designation IS NOT NULL)
      ORDER BY c.faculty_id, c.year ASC
    ),
    programs_with_data AS (
      SELECT DISTINCT INITCAP(g.program) as program
      FROM phd_grads g
      JOIN first_career fc ON fc.faculty_id = g.faculty_id
      WHERE g.program IS NOT NULL AND g.program != ''
        AND (p_from_year IS NULL OR fc.placement_year >= p_from_year)
        AND (p_to_year IS NULL OR fc.placement_year <= p_to_year)
    )
    SELECT json_agg(program ORDER BY program)
    FROM programs_with_data
  );
END;
$$;


--
-- Name: get_public_user_profile(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_public_user_profile(p_user_id uuid) RETURNS TABLE(id uuid, username text, avatar_url text, avatar_path text, is_private boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_public_user_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_public_user_stats(p_user_id uuid) RETURNS TABLE(is_private boolean, thread_count bigint, post_count bigint, upvotes_received bigint, downvotes_received bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_reserved_usernames(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_reserved_usernames() RETURNS text[]
    LANGUAGE sql STABLE
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


--
-- Name: get_thread_flag_reasons(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_thread_flag_reasons(p_title text, p_content text) RETURNS text[]
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_thread_view(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_thread_view(p_thread_id integer, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort text DEFAULT 'popular'::text) RETURNS TABLE(id integer, thread_id integer, parent_id integer, author_id uuid, author_name text, author_avatar text, author_avatar_path text, content text, additional_comments text, created_at timestamp with time zone, edited_at timestamp with time zone, likes bigint, dislikes bigint, user_vote integer, reply_count bigint, is_flagged boolean, flag_reason text, is_deleted boolean, deleted_by uuid, is_author_deleted boolean, is_op boolean, total_count bigint)
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


--
-- Name: get_threads_paginated(integer, integer, text, integer[], text, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_threads_paginated(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_sort_by text DEFAULT 'recent'::text, p_category_ids integer[] DEFAULT NULL::integer[], p_author_username text DEFAULT NULL::text, p_search_text text DEFAULT NULL::text, p_flagged_only boolean DEFAULT false, p_deleted_only boolean DEFAULT false) RETURNS TABLE(id integer, title text, author_id uuid, author_name text, author_avatar text, author_avatar_path text, created_at timestamp with time zone, first_post_content text, reply_count bigint, total_likes bigint, total_dislikes bigint, is_op_deleted boolean, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
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
    AND (p_search_text IS NULL OR text_contains_all_words(t.title || ' ' || op.content, p_search_text))
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
      count_visible_thread_replies(t.id, v_is_admin) AS reply_count,
      (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = 1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = op.id) AS total_likes,
      (SELECT COALESCE(SUM(CASE WHEN pv.vote_type = -1 THEN 1 ELSE 0 END), 0) FROM post_votes pv WHERE pv.post_id = op.id) AS total_dislikes,
      COALESCE(op.is_deleted, FALSE) AS is_op_deleted,
      v_total AS total_count
    FROM forum_threads t
    JOIN forum_posts op ON op.thread_id = t.id AND op.parent_id IS NULL
    JOIN user_profiles u ON u.id = t.author_id
    WHERE (p_category_ids IS NULL OR t.category_id = ANY(p_category_ids))
      AND (p_author_username IS NULL OR LOWER(u.username) = LOWER(p_author_username))
      AND (p_search_text IS NULL OR text_contains_all_words(t.title || ' ' || op.content, p_search_text))
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


--
-- Name: get_universities_for_program(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_universities_for_program(p_program text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN (
    SELECT json_agg(DISTINCT INITCAP(i.english_name) ORDER BY INITCAP(i.english_name))
    FROM pt_faculty_education e
    JOIN pt_institute i ON e.institution_id = i.id
    WHERE LOWER(e.degree) = 'phd'
      AND LOWER(e.field) = LOWER(p_program)
      AND i.english_name IS NOT NULL
      AND i.english_name != ''
  );
END;
$$;


--
-- Name: get_universities_for_program_year_range(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_universities_for_program_year_range(p_program text, p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer) RETURNS TABLE(university text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT INITCAP(i.english_name) as university
  FROM pt_faculty_education e
  JOIN pt_faculty_career c ON c.faculty_id = e.faculty_id
  JOIN pt_institute i ON e.institution_id = i.id
  WHERE LOWER(e.degree) = 'phd'
    AND LOWER(e.field) = LOWER(p_program)
    AND (c.designation IS NOT NULL OR c.institution_id IS NOT NULL)
    AND (p_from_year IS NULL OR e.year >= p_from_year)
    AND (p_to_year IS NULL OR e.year <= p_to_year)
  ORDER BY INITCAP(i.english_name);
END;
$$;


--
-- Name: get_unread_message_count(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_unread_message_count(p_user_id uuid) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id <> auth.uid() AND NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN (
    SELECT COUNT(*)
    FROM feedback_messages fm
    WHERE fm.recipient_id = p_user_id
      AND fm.is_read = FALSE
      AND NOT EXISTS (
        SELECT 1
        FROM ignored_users iu
        WHERE iu.user_id = auth.uid()
          AND iu.ignored_user_id = fm.user_id
      )
  );
END;
$$;


--
-- Name: get_user_bookmark_post_ids(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_bookmark_post_ids(p_user_id uuid) RETURNS integer[]
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_user_conversations(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_conversations(p_user_id uuid) RETURNS TABLE(conversation_partner_id uuid, partner_username text, partner_avatar text, partner_avatar_path text, last_message text, last_message_at timestamp with time zone, last_message_is_from_me boolean, unread_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
      AND NOT EXISTS (
        SELECT 1
        FROM ignored_users iu
        WHERE iu.user_id = auth.uid()
          AND iu.ignored_user_id = fm.user_id
      )
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


--
-- Name: get_user_post_bookmarks(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_post_bookmarks(p_post_ids integer[]) RETURNS TABLE(post_id integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT b.post_id
  FROM bookmarks b
  WHERE b.user_id = auth.uid()
    AND b.post_id = ANY(p_post_ids);
$$;


--
-- Name: get_user_post_overlays(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_post_overlays(p_post_ids integer[]) RETURNS TABLE(post_id integer, vote_type integer, is_bookmarked boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_user_post_votes(integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_post_votes(p_post_ids integer[]) RETURNS TABLE(post_id integer, vote_type integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT pv.post_id, pv.vote_type
  FROM post_votes pv
  WHERE pv.user_id = auth.uid()
    AND pv.post_id = ANY(p_post_ids);
$$;


--
-- Name: get_user_profile_cache(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_profile_cache(p_user_id uuid) RETURNS TABLE(id uuid, role text, is_blocked boolean, username text, avatar_url text, avatar_path text, is_private boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_users_paginated(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_users_paginated(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_search text DEFAULT NULL::text) RETURNS TABLE(id uuid, username text, email text, full_name text, avatar_url text, role text, is_blocked boolean, is_deleted boolean, created_at timestamp with time zone, last_login timestamp with time zone, last_ip inet, last_location text, thread_count bigint, post_count bigint, deleted_count bigint, flagged_count bigint, upvotes_received bigint, downvotes_received bigint, upvotes_given bigint, downvotes_given bigint, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_total BIGINT;
  v_search_pattern TEXT;
BEGIN
  IF NOT public.check_is_admin() THEN
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


--
-- Name: get_users_with_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_users_with_stats() RETURNS TABLE(id uuid, username text, email text, avatar_url text, role text, is_blocked boolean, is_deleted boolean, created_at timestamp with time zone, last_login timestamp with time zone, thread_count bigint, post_count bigint, flagged_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
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


--
-- Name: import_schools_from_json(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_schools_from_json(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ DECLARE v_uni_name TEXT; v_school TEXT; v_uni_id TEXT; v_added INTEGER := 0; v_existing INTEGER := 0; v_missing_univ INTEGER := 0; v_row_count INTEGER := 0; v_schools JSONB; BEGIN IF NOT public.check_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF; IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN RAISE EXCEPTION 'Payload must be a JSON object'; END IF; FOR v_uni_name, v_schools IN SELECT * FROM jsonb_each(p_payload) LOOP SELECT id INTO v_uni_id FROM pt_university WHERE LOWER(university) = LOWER(TRIM(v_uni_name)) LIMIT 1; IF v_uni_id IS NULL THEN v_missing_univ := v_missing_univ + 1; CONTINUE; END IF; IF jsonb_typeof(v_schools) <> 'array' THEN CONTINUE; END IF; FOR v_school IN SELECT jsonb_array_elements_text(v_schools) LOOP IF v_school IS NULL OR TRIM(v_school) = '' THEN CONTINUE; END IF; INSERT INTO pt_school (school, university_id) VALUES (v_school, v_uni_id) ON CONFLICT DO NOTHING; GET DIAGNOSTICS v_row_count = ROW_COUNT; IF v_row_count = 1 THEN v_added := v_added + 1; ELSE v_existing := v_existing + 1; END IF; END LOOP; END LOOP; RETURN jsonb_build_object('added', v_added, 'existing', v_existing, 'missing_universities', v_missing_univ); END; $$;


--
-- Name: is_not_blocked(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_not_blocked() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.is_blocked = true
  );
$$;


--
-- Name: is_user_ignored(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_user_ignored(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM ignored_users WHERE user_id = auth.uid() AND ignored_user_id = p_user_id);
END;
$$;


--
-- Name: is_username_available(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_username_available(p_username text) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: mark_conversation_read(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_conversation_read(p_user_id uuid, p_partner_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: notify_on_reply_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_on_reply_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: notify_on_reply_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_on_reply_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: notify_on_reply_visibility(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_on_reply_visibility() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: notify_on_vote_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_on_vote_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: notify_on_vote_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_on_vote_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: pt_program_lowercase(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pt_program_lowercase() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.program = LOWER(NEW.program);
    IF NEW.degree IS NOT NULL THEN
        NEW.degree = LOWER(NEW.degree);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: refresh_thread_search_document(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_thread_search_document(p_thread_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: refresh_thread_search_document_from_post(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_thread_search_document_from_post() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: refresh_thread_search_document_from_thread(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_thread_search_document_from_thread() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM refresh_thread_search_document(NEW.id);
  RETURN NEW;
END;
$$;


--
-- Name: reverse_search_placements(text, text, text, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_search_placements(p_placement_univ text, p_degree text DEFAULT NULL::text, p_program text DEFAULT NULL::text, p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0) RETURNS TABLE(id text, name text, placement_univ text, role text, year integer, university text, program text, degree text, discipline text, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH phd_grads AS (
    SELECT
      f.id as faculty_id,
      INITCAP(f.name) as name,
      INITCAP(e.field) as program,
      e.degree,
      e.year as phd_year,
      INITCAP(i.english_name) as phd_university
    FROM pt_faculty f
    JOIN pt_faculty_education e ON e.faculty_id = f.id AND LOWER(e.degree) = 'phd'
    LEFT JOIN pt_institute i ON e.institution_id = i.id
    WHERE
      (p_program IS NULL OR LOWER(e.field) = LOWER(p_program))
      AND (p_from_year IS NULL OR e.year >= p_from_year)
      AND (p_to_year IS NULL OR e.year <= p_to_year)
  ),
  first_career AS (
    SELECT DISTINCT ON (c.faculty_id)
      c.faculty_id,
      -- Priority: 1) school_id -> parent university, 2) institution matches school -> parent, 3) institution directly
      INITCAP(COALESCE(
        school_univ.english_name,
        matched_univ.english_name,
        pi.english_name,
        c.institution_name
      )) as placement_univ,
      INITCAP(c.designation) as role,
      c.year as placement_year
    FROM pt_faculty_career c
    JOIN phd_grads g ON c.faculty_id = g.faculty_id
    LEFT JOIN pt_institute pi ON c.institution_id = pi.id
    LEFT JOIN pt_school sc ON c.school_id = sc.id
    LEFT JOIN pt_institute school_univ ON sc.institution_id = school_univ.id
    LEFT JOIN pt_school matched_school ON LOWER(pi.english_name) = LOWER(matched_school.school)
    LEFT JOIN pt_institute matched_univ ON matched_school.institution_id = matched_univ.id
    WHERE (c.institution_name IS NOT NULL OR c.institution_id IS NOT NULL OR c.designation IS NOT NULL)
      AND (
        LOWER(COALESCE(school_univ.english_name, matched_univ.english_name, pi.english_name, c.institution_name))
        LIKE '%' || LOWER(p_placement_univ) || '%'
      )
    ORDER BY c.faculty_id, c.year ASC NULLS LAST
  ),
  filtered AS (
    SELECT
      g.faculty_id::text as id,
      g.name,
      fc.placement_univ,
      fc.role,
      g.phd_year as year,
      g.phd_university as university,
      g.program,
      g.degree,
      g.program as discipline
    FROM phd_grads g
    JOIN first_career fc ON fc.faculty_id = g.faculty_id
  ),
  counted AS (
    SELECT COUNT(*) AS cnt FROM filtered
  )
  SELECT
    f.id,
    f.name,
    f.placement_univ,
    f.role,
    f.year,
    f.university,
    f.program,
    f.degree,
    f.discipline,
    c.cnt AS total_count
  FROM filtered f, counted c
  ORDER BY f.year DESC NULLS LAST, f.name ASC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;


--
-- Name: search_placements(text, text, text, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_placements(p_degree text DEFAULT NULL::text, p_program text DEFAULT NULL::text, p_university text DEFAULT NULL::text, p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0) RETURNS TABLE(id text, name text, placement_univ text, role text, year integer, university text, program text, degree text, discipline text, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH phd_grads AS (
    SELECT
      f.id as faculty_id,
      INITCAP(f.name) as name,
      INITCAP(e.field) as program,
      e.degree,
      e.year as phd_year,
      INITCAP(i.english_name) as phd_university
    FROM pt_faculty f
    JOIN pt_faculty_education e ON e.faculty_id = f.id AND LOWER(e.degree) = 'phd'
    LEFT JOIN pt_institute i ON e.institution_id = i.id
    WHERE
      (p_program IS NULL OR LOWER(e.field) = LOWER(p_program))
      AND (p_university IS NULL OR LOWER(i.english_name) = LOWER(p_university))
      AND (p_from_year IS NULL OR e.year >= p_from_year)
      AND (p_to_year IS NULL OR e.year <= p_to_year)
  ),
  first_career AS (
    SELECT DISTINCT ON (c.faculty_id)
      c.faculty_id,
      -- Priority: 1) school_id -> parent university, 2) institution matches school -> parent, 3) institution directly
      INITCAP(COALESCE(
        school_univ.english_name,
        matched_univ.english_name,
        pi.english_name,
        c.institution_name
      )) as placement_univ,
      INITCAP(c.designation) as role,
      c.year as placement_year
    FROM pt_faculty_career c
    JOIN phd_grads g ON c.faculty_id = g.faculty_id
    LEFT JOIN pt_institute pi ON c.institution_id = pi.id
    LEFT JOIN pt_school sc ON c.school_id = sc.id
    LEFT JOIN pt_institute school_univ ON sc.institution_id = school_univ.id
    LEFT JOIN pt_school matched_school ON LOWER(pi.english_name) = LOWER(matched_school.school)
    LEFT JOIN pt_institute matched_univ ON matched_school.institution_id = matched_univ.id
    WHERE (c.institution_name IS NOT NULL OR c.institution_id IS NOT NULL OR c.designation IS NOT NULL)
    ORDER BY c.faculty_id, c.year ASC NULLS LAST
  ),
  filtered AS (
    SELECT
      g.faculty_id::text as id,
      g.name,
      fc.placement_univ,
      fc.role,
      g.phd_year as year,
      g.phd_university as university,
      g.program,
      g.degree,
      g.program as discipline
    FROM phd_grads g
    JOIN first_career fc ON fc.faculty_id = g.faculty_id
  ),
  counted AS (
    SELECT COUNT(*) AS cnt FROM filtered
  )
  SELECT
    f.id,
    f.name,
    f.placement_univ,
    f.role,
    f.year,
    f.university,
    f.program,
    f.degree,
    f.discipline,
    c.cnt AS total_count
  FROM filtered f, counted c
  ORDER BY f.year DESC NULLS LAST, f.name ASC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;


--
-- Name: set_user_blocked(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_user_blocked(p_user_id uuid, p_is_blocked boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NOT public.check_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE user_profiles SET is_blocked = p_is_blocked WHERE id = p_user_id;
  RETURN TRUE;
END;
$$;


--
-- Name: set_user_role(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_user_role(p_user_id uuid, p_role text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: toggle_ignore_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_ignore_user(p_ignored_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: toggle_post_bookmark(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_post_bookmark(p_post_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: toggle_post_flagged(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_post_flagged(p_post_id integer) RETURNS TABLE(success boolean, is_flagged boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: toggle_private(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_private(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_new_status BOOLEAN;
BEGIN
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Permission denied: can only toggle your own privacy';
  END IF;

  UPDATE user_profiles
  SET is_private = NOT COALESCE(is_private, FALSE)
  WHERE id = p_user_id
  RETURNING is_private INTO v_new_status;

  RETURN v_new_status;
END;
$$;


--
-- Name: toggle_thread_bookmark(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_thread_bookmark(p_thread_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: trigger_refresh_thread_search_on_post_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_refresh_thread_search_on_post_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM refresh_thread_search_document(OLD.thread_id);
  RETURN OLD;
END;
$$;


--
-- Name: trigger_refresh_thread_search_on_post_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_refresh_thread_search_on_post_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM refresh_thread_search_document(NEW.thread_id);
  RETURN NEW;
END;
$$;


--
-- Name: trigger_refresh_thread_search_on_post_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_refresh_thread_search_on_post_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM refresh_thread_search_document(NEW.thread_id);
  RETURN NEW;
END;
$$;


--
-- Name: trigger_refresh_thread_search_on_thread(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_refresh_thread_search_on_thread() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM refresh_thread_search_document(NEW.id);
  RETURN NEW;
END;
$$;


--
-- Name: update_faculty_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_faculty_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pt_faculty SET updated_at = NOW() WHERE id = NEW.faculty_id;
    RETURN NEW;
END;
$$;


--
-- Name: update_login_metadata(timestamp with time zone, inet, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_login_metadata(p_last_login timestamp with time zone DEFAULT NULL::timestamp with time zone, p_last_ip inet DEFAULT NULL::inet, p_last_location text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: update_post_reply_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_reply_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_post_reply_count_on_visibility(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_reply_count_on_visibility() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_post_search_document(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_search_document() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.search_document := to_tsvector(
    'simple',
    COALESCE(NEW.content, '') || ' ' || COALESCE(NEW.additional_comments, '')
  );
  RETURN NEW;
END;
$$;


--
-- Name: update_post_vote_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_vote_counts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_pt_faculty_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_pt_faculty_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_pt_school_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_pt_school_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;


--
-- Name: update_thread_last_activity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_thread_last_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE forum_threads
  SET last_activity = NEW.created_at
  WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_user_stats_on_post_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_post_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_user_stats_on_post_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_post_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_user_stats_on_post_visibility(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_post_visibility() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_user_stats_on_thread_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_thread_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_user_stats_on_vote_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_vote_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_user_stats_on_vote_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_stats_on_vote_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_username(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_username(p_new_username text) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_current_username TEXT;
  v_lower_username TEXT;
  v_reserved_usernames TEXT[] := get_reserved_usernames();
BEGIN
  v_lower_username := LOWER(p_new_username);

  SELECT username INTO v_current_username FROM user_profiles WHERE id = auth.uid();

  IF LOWER(v_current_username) = v_lower_username THEN
    RETURN QUERY SELECT TRUE, 'Username unchanged'::TEXT;
    RETURN;
  END IF;

  IF v_lower_username = ANY(v_reserved_usernames) THEN
    RETURN QUERY SELECT FALSE, 'Username not available'::TEXT;
    RETURN;
  END IF;

  -- Block any username containing "moderator" or "admin"
  IF v_lower_username LIKE '%moderator%' OR v_lower_username LIKE '%admin%' THEN
    RETURN QUERY SELECT FALSE, 'Username not available'::TEXT;
    RETURN;
  END IF;

  -- Only exact "PandaKeeper" allowed (no variants like Panda_Keeper, PandaKeeper1, etc.)
  IF v_lower_username LIKE '%pandakeeper%' AND v_lower_username != 'pandakeeper' THEN
    RETURN QUERY SELECT FALSE, 'Username not available'::TEXT;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM user_profiles WHERE LOWER(username) = v_lower_username AND id != auth.uid()) THEN
    RETURN QUERY SELECT FALSE, 'Username not available'::TEXT;
    RETURN;
  END IF;

  UPDATE user_profiles SET username = p_new_username WHERE id = auth.uid();
  RETURN QUERY SELECT TRUE, 'Username updated successfully'::TEXT;
END;
$$;


--
-- Name: vote_poll(integer, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.vote_poll(p_poll_id integer, p_option_ids integer[]) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: vote_post(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.vote_post(p_post_id integer, p_vote_type integer) RETURNS TABLE(likes bigint, dislikes bigint, user_vote integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookmarks (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    post_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bookmarks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bookmarks_id_seq OWNED BY public.bookmarks.id;


--
-- Name: debug_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.debug_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: debug_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.debug_log_id_seq OWNED BY public.debug_log.id;


--
-- Name: feedback_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedback_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    recipient_id uuid,
    content text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_posts (
    id integer NOT NULL,
    thread_id integer NOT NULL,
    parent_id integer,
    author_id uuid NOT NULL,
    content text NOT NULL,
    additional_comments text,
    is_flagged boolean DEFAULT false,
    flag_reason text,
    is_deleted boolean DEFAULT false,
    deleted_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    edited_at timestamp with time zone,
    likes bigint DEFAULT 0,
    dislikes bigint DEFAULT 0,
    reply_count bigint DEFAULT 0,
    search_document tsvector
);


--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_posts_id_seq OWNED BY public.forum_posts.id;


--
-- Name: forum_threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_threads (
    id integer NOT NULL,
    title text NOT NULL,
    category_id integer,
    author_id uuid NOT NULL,
    is_flagged boolean DEFAULT false,
    flag_reason text,
    created_at timestamp with time zone DEFAULT now(),
    last_activity timestamp with time zone DEFAULT now(),
    search_document tsvector
);


--
-- Name: forum_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_threads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_threads_id_seq OWNED BY public.forum_threads.id;


--
-- Name: ignored_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ignored_users (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    ignored_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ignored_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ignored_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ignored_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ignored_users_id_seq OWNED BY public.ignored_users.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    post_id integer NOT NULL,
    thread_id integer NOT NULL,
    reply_count integer DEFAULT 0,
    upvotes integer DEFAULT 0,
    downvotes integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    baseline_reply_count integer DEFAULT 0,
    baseline_upvotes integer DEFAULT 0,
    baseline_downvotes integer DEFAULT 0
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: poll_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_options (
    id integer NOT NULL,
    poll_id integer NOT NULL,
    option_text text NOT NULL,
    display_order integer DEFAULT 0
);


--
-- Name: poll_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.poll_options_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: poll_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.poll_options_id_seq OWNED BY public.poll_options.id;


--
-- Name: poll_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_votes (
    id integer NOT NULL,
    poll_id integer NOT NULL,
    option_id integer NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: poll_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.poll_votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: poll_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.poll_votes_id_seq OWNED BY public.poll_votes.id;


--
-- Name: polls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.polls (
    id integer NOT NULL,
    thread_id integer,
    allow_multiple boolean DEFAULT false,
    allow_vote_change boolean DEFAULT true,
    show_results_before_vote boolean DEFAULT false,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: polls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.polls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: polls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.polls_id_seq OWNED BY public.polls.id;


--
-- Name: post_bookmarks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.post_bookmarks AS
 SELECT id,
    user_id,
    post_id,
    created_at
   FROM public.bookmarks;


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_votes (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id uuid NOT NULL,
    vote_type integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT post_votes_vote_type_check CHECK ((vote_type = ANY (ARRAY[1, '-1'::integer])))
);


--
-- Name: post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_votes_id_seq OWNED BY public.post_votes.id;


--
-- Name: pt_academic_programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_academic_programs (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    degree text NOT NULL,
    department_id text NOT NULL,
    program_name text NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    placement_url text[],
    last_parsed_in_ist timestamp with time zone,
    alias text
);


--
-- Name: TABLE pt_academic_programs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.pt_academic_programs IS 'Academic programs offered by departments, unique by degree type, department, and program name';


--
-- Name: COLUMN pt_academic_programs.last_parsed_in_ist; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_academic_programs.last_parsed_in_ist IS 'Time of last parsing of placement URLs in IST';


--
-- Name: pt_career; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_career (
    id text NOT NULL,
    person_id text,
    year integer,
    designation text,
    institution_id text,
    school_id text,
    department_id text,
    updated_at timestamp with time zone
);


--
-- Name: pt_country; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_country (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: pt_department; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_department (
    id text NOT NULL,
    department text,
    school_id text,
    status text,
    url text,
    faculty_url text,
    flagged text DEFAULT 'false'::text,
    updated_at timestamp with time zone DEFAULT now(),
    parsed boolean DEFAULT false,
    scraper text,
    is_404 boolean DEFAULT false,
    website_type text DEFAULT ''::text,
    parsing_comment text DEFAULT ''::text
);


--
-- Name: pt_education; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_education (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    person_id text,
    degree text,
    field text,
    institution_id text,
    institution_name text,
    year integer,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: pt_faculty; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_faculty (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    institution_id text,
    school_id text,
    department_id text,
    profile_url text NOT NULL,
    cv_url text,
    personal_url text,
    google_scholar text,
    linkedin text,
    personal_phone text,
    official_phone text,
    personal_email text,
    official_email text,
    updated_at timestamp with time zone DEFAULT now(),
    source text,
    gender text,
    designation text DEFAULT ''::text,
    academia_edu text
);


--
-- Name: pt_faculty_career; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_faculty_career (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    faculty_id uuid,
    year integer,
    designation text,
    institution_id text,
    school_id text,
    department_id text,
    updated_at timestamp with time zone DEFAULT now(),
    institution_name text
);


--
-- Name: pt_faculty_education; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_faculty_education (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    faculty_id uuid,
    degree text,
    field text,
    institution_id text,
    year integer,
    updated_at timestamp with time zone DEFAULT now(),
    advisor text,
    committee text[],
    thesis text,
    program_id text
);


--
-- Name: pt_institute; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_institute (
    id text NOT NULL,
    name text NOT NULL,
    url text NOT NULL,
    us_news_2025_rank integer,
    updated_at timestamp with time zone,
    country_id text NOT NULL,
    type text DEFAULT 'university'::text NOT NULL,
    parent_institution_id text,
    faculty_url text,
    scraper text,
    parsed boolean DEFAULT false,
    is_404 boolean DEFAULT false,
    website_type text DEFAULT ''::text,
    parsing_comment text DEFAULT ''::text
);


--
-- Name: COLUMN pt_institute.parent_institution_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.parent_institution_id IS 'Parent institution ID for hierarchical relationships (e.g., lab -> university, department -> university)';


--
-- Name: pt_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_people (
    id text NOT NULL,
    name text,
    phd_program_id text,
    phd_year integer,
    phd_advisor text,
    phd_dissertation_title text,
    phd_thesis_committee text,
    linkedin_url text,
    google_scholar_url text,
    email text,
    updated_at timestamp with time zone,
    profile_url text,
    phd_institution text
);


--
-- Name: pt_program_university; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_program_university (
    id text NOT NULL,
    program text,
    university text,
    program_id text,
    university_id text
);


--
-- Name: pt_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_queue (
    id text NOT NULL,
    program_id text,
    status text,
    "timestamp" timestamp with time zone,
    processed boolean DEFAULT false,
    processed_at timestamp with time zone
);


--
-- Name: pt_school; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_school (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    school text NOT NULL,
    institution_id text,
    url text,
    updated_at timestamp with time zone DEFAULT now(),
    type public.school_type DEFAULT 'degree_granting'::public.school_type,
    faculty_url text,
    flagged text DEFAULT 'false'::text,
    parsed boolean DEFAULT false,
    scraper text,
    is_404 boolean DEFAULT false,
    website_type text DEFAULT ''::text,
    parsing_comment text DEFAULT ''::text
);


--
-- Name: pt_source; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_source (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    url text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: pt_univ_program_combined; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pt_univ_program_combined (
    id text NOT NULL,
    program text,
    university text
);


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    id uuid NOT NULL,
    username text NOT NULL,
    avatar_url text,
    avatar_index integer DEFAULT 0,
    role text DEFAULT 'user'::text,
    is_blocked boolean DEFAULT false,
    is_deleted boolean DEFAULT false,
    is_private boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    last_login timestamp with time zone,
    last_ip inet,
    last_location text,
    avatar_path text,
    CONSTRAINT user_profiles_role_check CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text])))
);


--
-- Name: user_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stats (
    user_id uuid NOT NULL,
    thread_count bigint DEFAULT 0,
    post_count bigint DEFAULT 0,
    deleted_count bigint DEFAULT 0,
    flagged_count bigint DEFAULT 0,
    upvotes_received bigint DEFAULT 0,
    downvotes_received bigint DEFAULT 0,
    upvotes_given bigint DEFAULT 0,
    downvotes_given bigint DEFAULT 0,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: bookmarks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN id SET DEFAULT nextval('public.bookmarks_id_seq'::regclass);


--
-- Name: forum_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts ALTER COLUMN id SET DEFAULT nextval('public.forum_posts_id_seq'::regclass);


--
-- Name: forum_threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_threads ALTER COLUMN id SET DEFAULT nextval('public.forum_threads_id_seq'::regclass);


--
-- Name: ignored_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users ALTER COLUMN id SET DEFAULT nextval('public.ignored_users_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: poll_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options ALTER COLUMN id SET DEFAULT nextval('public.poll_options_id_seq'::regclass);


--
-- Name: poll_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes ALTER COLUMN id SET DEFAULT nextval('public.poll_votes_id_seq'::regclass);


--
-- Name: polls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls ALTER COLUMN id SET DEFAULT nextval('public.polls_id_seq'::regclass);


--
-- Name: post_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes ALTER COLUMN id SET DEFAULT nextval('public.post_votes_id_seq'::regclass);


--
-- Name: bookmarks bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);


--
-- Name: bookmarks bookmarks_user_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_user_id_post_id_key UNIQUE (user_id, post_id);


--
-- Name: feedback_messages feedback_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_messages
    ADD CONSTRAINT feedback_messages_pkey PRIMARY KEY (id);


--
-- Name: forum_posts forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: forum_threads forum_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_threads
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (id);


--
-- Name: ignored_users ignored_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users
    ADD CONSTRAINT ignored_users_pkey PRIMARY KEY (id);


--
-- Name: ignored_users ignored_users_user_id_ignored_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users
    ADD CONSTRAINT ignored_users_user_id_ignored_user_id_key UNIQUE (user_id, ignored_user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_user_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_post_id_key UNIQUE (user_id, post_id);


--
-- Name: poll_options poll_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_pkey PRIMARY KEY (id);


--
-- Name: poll_votes poll_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_pkey PRIMARY KEY (id);


--
-- Name: poll_votes poll_votes_poll_id_option_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_poll_id_option_id_user_id_key UNIQUE (poll_id, option_id, user_id);


--
-- Name: polls polls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_pkey PRIMARY KEY (id);


--
-- Name: polls polls_thread_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_thread_id_key UNIQUE (thread_id);


--
-- Name: post_votes post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (id);


--
-- Name: post_votes post_votes_post_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_post_id_user_id_key UNIQUE (post_id, user_id);


--
-- Name: pt_academic_programs pt_academic_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_academic_programs
    ADD CONSTRAINT pt_academic_programs_pkey PRIMARY KEY (id);


--
-- Name: pt_academic_programs pt_academic_programs_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_academic_programs
    ADD CONSTRAINT pt_academic_programs_unique UNIQUE (degree, department_id, program_name);


--
-- Name: pt_career pt_career_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_career
    ADD CONSTRAINT pt_career_pkey1 PRIMARY KEY (id);


--
-- Name: pt_country pt_country_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_country
    ADD CONSTRAINT pt_country_code_key UNIQUE (code);


--
-- Name: pt_country pt_country_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_country
    ADD CONSTRAINT pt_country_name_key UNIQUE (name);


--
-- Name: pt_country pt_country_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_country
    ADD CONSTRAINT pt_country_pkey PRIMARY KEY (id);


--
-- Name: pt_department pt_department_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_department
    ADD CONSTRAINT pt_department_pkey PRIMARY KEY (id);


--
-- Name: pt_education pt_education_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_education
    ADD CONSTRAINT pt_education_pkey PRIMARY KEY (id);


--
-- Name: pt_faculty_career pt_faculty_career_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_career
    ADD CONSTRAINT pt_faculty_career_pkey PRIMARY KEY (id);


--
-- Name: pt_faculty_education pt_faculty_education_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_education
    ADD CONSTRAINT pt_faculty_education_pkey PRIMARY KEY (id);


--
-- Name: pt_faculty pt_faculty_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty
    ADD CONSTRAINT pt_faculty_pkey PRIMARY KEY (id);


--
-- Name: pt_people pt_people_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_people
    ADD CONSTRAINT pt_people_pkey1 PRIMARY KEY (id);


--
-- Name: pt_program_university pt_program_university_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_program_university
    ADD CONSTRAINT pt_program_university_pkey PRIMARY KEY (id);


--
-- Name: pt_queue pt_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_queue
    ADD CONSTRAINT pt_queue_pkey PRIMARY KEY (id);


--
-- Name: pt_school pt_school_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_school
    ADD CONSTRAINT pt_school_pkey PRIMARY KEY (id);


--
-- Name: pt_source pt_source_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_source
    ADD CONSTRAINT pt_source_pkey PRIMARY KEY (id);


--
-- Name: pt_univ_program_combined pt_univ_program_combined_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_univ_program_combined
    ADD CONSTRAINT pt_univ_program_combined_pkey PRIMARY KEY (id);


--
-- Name: pt_institute pt_university_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_institute
    ADD CONSTRAINT pt_university_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_username_key UNIQUE (username);


--
-- Name: user_stats user_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_pkey PRIMARY KEY (user_id);


--
-- Name: idx_academic_programs_degree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_academic_programs_degree ON public.pt_academic_programs USING btree (degree);


--
-- Name: idx_academic_programs_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_academic_programs_department ON public.pt_academic_programs USING btree (department_id);


--
-- Name: idx_bookmarks_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookmarks_user ON public.bookmarks USING btree (user_id);


--
-- Name: idx_bookmarks_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookmarks_user_created ON public.bookmarks USING btree (user_id, created_at DESC);


--
-- Name: idx_feedback_messages_pair_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_pair_created ON public.feedback_messages USING btree (user_id, recipient_id, created_at DESC);


--
-- Name: idx_feedback_messages_pair_created_reverse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_pair_created_reverse ON public.feedback_messages USING btree (recipient_id, user_id, created_at DESC);


--
-- Name: idx_feedback_messages_recipient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_recipient ON public.feedback_messages USING btree (recipient_id, created_at DESC);


--
-- Name: idx_feedback_messages_recipient_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_recipient_unread ON public.feedback_messages USING btree (recipient_id) WHERE (is_read = false);


--
-- Name: idx_feedback_messages_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_unread ON public.feedback_messages USING btree (recipient_id, user_id, created_at DESC) WHERE (is_read = false);


--
-- Name: idx_feedback_messages_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedback_messages_user ON public.feedback_messages USING btree (user_id, created_at DESC);


--
-- Name: idx_forum_posts_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_author ON public.forum_posts USING btree (author_id);


--
-- Name: idx_forum_posts_author_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_author_created ON public.forum_posts USING btree (author_id, created_at DESC);


--
-- Name: idx_forum_posts_content_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_content_trgm ON public.forum_posts USING gin (lower(content) public.gin_trgm_ops);


--
-- Name: idx_forum_posts_flagged; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_flagged ON public.forum_posts USING btree (is_flagged) WHERE (is_flagged = true);


--
-- Name: idx_forum_posts_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_parent ON public.forum_posts USING btree (parent_id);


--
-- Name: idx_forum_posts_search_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_search_document ON public.forum_posts USING gin (search_document);


--
-- Name: idx_forum_posts_thread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_thread ON public.forum_posts USING btree (thread_id);


--
-- Name: idx_forum_posts_thread_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_thread_created ON public.forum_posts USING btree (thread_id, created_at DESC);


--
-- Name: idx_forum_posts_thread_op; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_thread_op ON public.forum_posts USING btree (thread_id) WHERE (parent_id IS NULL);


--
-- Name: idx_forum_posts_thread_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_thread_parent ON public.forum_posts USING btree (thread_id, parent_id);


--
-- Name: idx_forum_posts_thread_parent_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_posts_thread_parent_created ON public.forum_posts USING btree (thread_id, parent_id, created_at DESC);


--
-- Name: idx_forum_threads_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_author ON public.forum_threads USING btree (author_id);


--
-- Name: idx_forum_threads_author_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_author_created ON public.forum_threads USING btree (author_id, created_at DESC);


--
-- Name: idx_forum_threads_category_last_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_category_last_activity ON public.forum_threads USING btree (category_id, last_activity DESC);


--
-- Name: idx_forum_threads_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_created ON public.forum_threads USING btree (created_at DESC);


--
-- Name: idx_forum_threads_flagged; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_flagged ON public.forum_threads USING btree (is_flagged) WHERE (is_flagged = true);


--
-- Name: idx_forum_threads_last_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_last_activity ON public.forum_threads USING btree (last_activity DESC);


--
-- Name: idx_forum_threads_search_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_search_document ON public.forum_threads USING gin (search_document);


--
-- Name: idx_forum_threads_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_forum_threads_title_trgm ON public.forum_threads USING gin (lower(title) public.gin_trgm_ops);


--
-- Name: idx_ignored_users_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ignored_users_user ON public.ignored_users USING btree (user_id);


--
-- Name: idx_institution_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_institution_name_trgm ON public.pt_institute USING gin (lower(name) public.gin_trgm_ops);


--
-- Name: idx_institution_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_institution_parent ON public.pt_institute USING btree (parent_institution_id) WHERE (parent_institution_id IS NOT NULL);


--
-- Name: idx_notifications_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_post ON public.notifications USING btree (post_id);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id, updated_at DESC);


--
-- Name: idx_poll_options_poll; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_poll_options_poll ON public.poll_options USING btree (poll_id);


--
-- Name: idx_poll_votes_option; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_poll_votes_option ON public.poll_votes USING btree (option_id);


--
-- Name: idx_poll_votes_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_poll_votes_user ON public.poll_votes USING btree (poll_id, user_id);


--
-- Name: idx_post_votes_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_votes_post ON public.post_votes USING btree (post_id);


--
-- Name: idx_post_votes_post_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_votes_post_type ON public.post_votes USING btree (post_id, vote_type);


--
-- Name: idx_post_votes_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_votes_user ON public.post_votes USING btree (user_id);


--
-- Name: idx_post_votes_user_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_votes_user_post ON public.post_votes USING btree (user_id, post_id);


--
-- Name: idx_pt_career_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_career_institution ON public.pt_career USING btree (institution_id);


--
-- Name: idx_pt_career_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_career_person ON public.pt_career USING btree (person_id);


--
-- Name: idx_pt_career_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_career_year ON public.pt_career USING btree (year);


--
-- Name: idx_pt_department_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_department_name_unique ON public.pt_department USING btree (school_id, lower(department));


--
-- Name: idx_pt_department_school; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_department_school ON public.pt_department USING btree (school_id);


--
-- Name: idx_pt_department_unique_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_department_unique_lower ON public.pt_department USING btree (lower(department), school_id);


--
-- Name: idx_pt_education_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_education_institution ON public.pt_education USING btree (institution_id);


--
-- Name: idx_pt_education_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_education_person ON public.pt_education USING btree (person_id);


--
-- Name: idx_pt_education_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_education_year ON public.pt_education USING btree (year);


--
-- Name: idx_pt_faculty_career_faculty; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_career_faculty ON public.pt_faculty_career USING btree (faculty_id);


--
-- Name: idx_pt_faculty_career_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_career_institution ON public.pt_faculty_career USING btree (institution_id);


--
-- Name: idx_pt_faculty_career_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_career_year ON public.pt_faculty_career USING btree (year);


--
-- Name: idx_pt_faculty_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_department ON public.pt_faculty USING btree (department_id);


--
-- Name: idx_pt_faculty_education_faculty; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_education_faculty ON public.pt_faculty_education USING btree (faculty_id);


--
-- Name: idx_pt_faculty_education_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_education_institution ON public.pt_faculty_education USING btree (institution_id);


--
-- Name: idx_pt_faculty_education_program; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_education_program ON public.pt_faculty_education USING btree (program_id);


--
-- Name: idx_pt_faculty_education_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_education_year ON public.pt_faculty_education USING btree (year);


--
-- Name: idx_pt_faculty_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_institution ON public.pt_faculty USING btree (institution_id);


--
-- Name: idx_pt_faculty_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_name ON public.pt_faculty USING btree (name);


--
-- Name: idx_pt_faculty_name_profile_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_faculty_name_profile_url ON public.pt_faculty USING btree (name, profile_url);


--
-- Name: idx_pt_faculty_school; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_faculty_school ON public.pt_faculty USING btree (school_id);


--
-- Name: idx_pt_people_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_people_name ON public.pt_people USING btree (name);


--
-- Name: idx_pt_people_program; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_people_program ON public.pt_people USING btree (phd_program_id);


--
-- Name: idx_pt_queue_program; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_queue_program ON public.pt_queue USING btree (program_id);


--
-- Name: idx_pt_school_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_school_name_unique ON public.pt_school USING btree (institution_id, lower(school));


--
-- Name: idx_pt_school_university; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pt_school_university ON public.pt_school USING btree (institution_id);


--
-- Name: idx_pt_school_university_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_school_university_name_unique ON public.pt_school USING btree (institution_id, lower(school));


--
-- Name: idx_pt_source_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_source_name ON public.pt_source USING btree (name);


--
-- Name: idx_user_stats_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_stats_updated ON public.user_stats USING btree (updated_at DESC);


--
-- Name: pt_institution_name_country_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pt_institution_name_country_unique ON public.pt_institute USING btree (lower(name), country_id);


--
-- Name: user_profiles_username_lower_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_profiles_username_lower_idx ON public.user_profiles USING btree (lower(username));


--
-- Name: pt_department enforce_lowercase_department_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_lowercase_department_trigger BEFORE INSERT OR UPDATE ON public.pt_department FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_department();


--
-- Name: pt_faculty_education enforce_lowercase_faculty_education_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_lowercase_faculty_education_trigger BEFORE INSERT OR UPDATE ON public.pt_faculty_education FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_pt_faculty_education();


--
-- Name: pt_faculty_education enforce_lowercase_field_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_lowercase_field_trigger BEFORE INSERT OR UPDATE ON public.pt_faculty_education FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_field();


--
-- Name: pt_institute enforce_lowercase_institution_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_lowercase_institution_trigger BEFORE INSERT OR UPDATE ON public.pt_institute FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_institution();


--
-- Name: pt_school enforce_lowercase_school_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_lowercase_school_trigger BEFORE INSERT OR UPDATE ON public.pt_school FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_school();


--
-- Name: pt_academic_programs pt_academic_programs_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_academic_programs_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_academic_programs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_career pt_career_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_career_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_career FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_country pt_country_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_country_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_country FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_department pt_department_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_department_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_department FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_education pt_education_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_education_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_education FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_faculty_career pt_faculty_career_update_faculty_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_career_update_faculty_timestamp AFTER INSERT OR DELETE OR UPDATE ON public.pt_faculty_career FOR EACH ROW EXECUTE FUNCTION public.update_faculty_updated_at();


--
-- Name: pt_faculty_career pt_faculty_career_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_career_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_faculty_career FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_faculty_education pt_faculty_education_update_faculty_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_education_update_faculty_timestamp AFTER INSERT OR DELETE OR UPDATE ON public.pt_faculty_education FOR EACH ROW EXECUTE FUNCTION public.update_faculty_updated_at();


--
-- Name: pt_faculty_education pt_faculty_education_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_education_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_faculty_education FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_faculty pt_faculty_lowercase_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_lowercase_name BEFORE INSERT OR UPDATE ON public.pt_faculty FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_pt_faculty();


--
-- Name: pt_faculty pt_faculty_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_faculty FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_institute pt_institution_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_institution_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_institute FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_people pt_people_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_people_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_people FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_school pt_school_update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_school_update_timestamp BEFORE INSERT OR UPDATE ON public.pt_school FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pt_country trigger_enforce_lowercase_country; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_enforce_lowercase_country BEFORE INSERT OR UPDATE ON public.pt_country FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_country();


--
-- Name: user_profiles trigger_ensure_user_stats; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ensure_user_stats AFTER INSERT ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.ensure_user_stats();


--
-- Name: pt_people trigger_lowercase_pt_people_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_lowercase_pt_people_name BEFORE INSERT OR UPDATE ON public.pt_people FOR EACH ROW EXECUTE FUNCTION public.enforce_lowercase_pt_people_name();


--
-- Name: forum_posts trigger_notify_on_reply_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_reply_delete AFTER DELETE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.notify_on_reply_delete();


--
-- Name: forum_posts trigger_notify_on_reply_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_reply_insert AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.notify_on_reply_insert();


--
-- Name: forum_posts trigger_notify_on_reply_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_reply_visibility AFTER UPDATE OF is_deleted ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.notify_on_reply_visibility();


--
-- Name: post_votes trigger_notify_on_vote_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_vote_delete AFTER DELETE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.notify_on_vote_delete();


--
-- Name: post_votes trigger_notify_on_vote_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_vote_insert AFTER INSERT ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.notify_on_vote_change();


--
-- Name: post_votes trigger_notify_on_vote_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_notify_on_vote_update AFTER UPDATE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.notify_on_vote_change();


--
-- Name: pt_school trigger_pt_school_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_pt_school_updated_at BEFORE UPDATE ON public.pt_school FOR EACH ROW EXECUTE FUNCTION public.update_pt_school_updated_at();


--
-- Name: forum_threads trigger_refresh_thread_search_document; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_refresh_thread_search_document AFTER INSERT OR UPDATE OF title ON public.forum_threads FOR EACH ROW EXECUTE FUNCTION public.refresh_thread_search_document_from_thread();


--
-- Name: forum_posts trigger_refresh_thread_search_document_op_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_refresh_thread_search_document_op_delete AFTER DELETE ON public.forum_posts FOR EACH ROW WHEN ((old.parent_id IS NULL)) EXECUTE FUNCTION public.refresh_thread_search_document_from_post();


--
-- Name: forum_posts trigger_refresh_thread_search_document_op_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_refresh_thread_search_document_op_insert AFTER INSERT ON public.forum_posts FOR EACH ROW WHEN ((new.parent_id IS NULL)) EXECUTE FUNCTION public.refresh_thread_search_document_from_post();


--
-- Name: forum_posts trigger_refresh_thread_search_document_op_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_refresh_thread_search_document_op_update AFTER UPDATE OF content, additional_comments ON public.forum_posts FOR EACH ROW WHEN ((new.parent_id IS NULL)) EXECUTE FUNCTION public.refresh_thread_search_document_from_post();


--
-- Name: forum_posts trigger_update_post_reply_count_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_reply_count_delete AFTER DELETE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_post_reply_count();


--
-- Name: forum_posts trigger_update_post_reply_count_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_reply_count_insert AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_post_reply_count();


--
-- Name: forum_posts trigger_update_post_reply_count_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_reply_count_visibility AFTER UPDATE OF is_deleted ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_post_reply_count_on_visibility();


--
-- Name: forum_posts trigger_update_post_search_document; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_search_document BEFORE INSERT OR UPDATE OF content, additional_comments ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_post_search_document();


--
-- Name: post_votes trigger_update_post_vote_counts_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_vote_counts_delete AFTER DELETE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_post_vote_counts();


--
-- Name: post_votes trigger_update_post_vote_counts_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_vote_counts_insert AFTER INSERT ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_post_vote_counts();


--
-- Name: post_votes trigger_update_post_vote_counts_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_post_vote_counts_update AFTER UPDATE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_post_vote_counts();


--
-- Name: forum_posts trigger_update_thread_last_activity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_thread_last_activity AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_thread_last_activity();


--
-- Name: forum_posts trigger_update_user_stats_post_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_post_delete AFTER DELETE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_post_delete();


--
-- Name: forum_posts trigger_update_user_stats_post_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_post_insert AFTER INSERT ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_post_insert();


--
-- Name: forum_posts trigger_update_user_stats_post_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_post_visibility AFTER UPDATE OF is_deleted, is_flagged ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_post_visibility();


--
-- Name: forum_threads trigger_update_user_stats_thread_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_thread_delete AFTER DELETE ON public.forum_threads FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_thread_change();


--
-- Name: forum_threads trigger_update_user_stats_thread_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_thread_insert AFTER INSERT ON public.forum_threads FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_thread_change();


--
-- Name: post_votes trigger_update_user_stats_vote_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_vote_delete AFTER DELETE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_vote_delete();


--
-- Name: post_votes trigger_update_user_stats_vote_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_vote_insert AFTER INSERT ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_vote_change();


--
-- Name: post_votes trigger_update_user_stats_vote_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_user_stats_vote_update AFTER UPDATE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION public.update_user_stats_on_vote_change();


--
-- Name: bookmarks bookmarks_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: bookmarks bookmarks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: feedback_messages feedback_messages_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_messages
    ADD CONSTRAINT feedback_messages_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: feedback_messages feedback_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_messages
    ADD CONSTRAINT feedback_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: forum_posts forum_posts_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: forum_posts forum_posts_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.user_profiles(id);


--
-- Name: forum_posts forum_posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: forum_posts forum_posts_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.forum_threads(id) ON DELETE CASCADE;


--
-- Name: forum_threads forum_threads_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_threads
    ADD CONSTRAINT forum_threads_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: ignored_users ignored_users_ignored_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users
    ADD CONSTRAINT ignored_users_ignored_user_id_fkey FOREIGN KEY (ignored_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: ignored_users ignored_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users
    ADD CONSTRAINT ignored_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.forum_threads(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: poll_options poll_options_poll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_poll_id_fkey FOREIGN KEY (poll_id) REFERENCES public.polls(id) ON DELETE CASCADE;


--
-- Name: poll_votes poll_votes_option_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_option_id_fkey FOREIGN KEY (option_id) REFERENCES public.poll_options(id) ON DELETE CASCADE;


--
-- Name: poll_votes poll_votes_poll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_poll_id_fkey FOREIGN KEY (poll_id) REFERENCES public.polls(id) ON DELETE CASCADE;


--
-- Name: poll_votes poll_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: polls polls_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.forum_threads(id) ON DELETE CASCADE;


--
-- Name: post_votes post_votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: post_votes post_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: pt_academic_programs pt_academic_programs_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_academic_programs
    ADD CONSTRAINT pt_academic_programs_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.pt_department(id);


--
-- Name: pt_career pt_career_institution_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_career
    ADD CONSTRAINT pt_career_institution_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_career pt_career_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_career
    ADD CONSTRAINT pt_career_person_fkey FOREIGN KEY (person_id) REFERENCES public.pt_people(id) ON DELETE CASCADE;


--
-- Name: pt_department pt_department_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_department
    ADD CONSTRAINT pt_department_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.pt_school(id) ON DELETE CASCADE;


--
-- Name: pt_education pt_education_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_education
    ADD CONSTRAINT pt_education_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_education pt_education_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_education
    ADD CONSTRAINT pt_education_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.pt_people(id) ON DELETE CASCADE;


--
-- Name: pt_faculty_career pt_faculty_career_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_career
    ADD CONSTRAINT pt_faculty_career_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.pt_department(id);


--
-- Name: pt_faculty_career pt_faculty_career_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_career
    ADD CONSTRAINT pt_faculty_career_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.pt_faculty(id) ON DELETE CASCADE;


--
-- Name: pt_faculty_career pt_faculty_career_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_career
    ADD CONSTRAINT pt_faculty_career_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_faculty_career pt_faculty_career_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_career
    ADD CONSTRAINT pt_faculty_career_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.pt_school(id);


--
-- Name: pt_faculty pt_faculty_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty
    ADD CONSTRAINT pt_faculty_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.pt_department(id);


--
-- Name: pt_faculty_education pt_faculty_education_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_education
    ADD CONSTRAINT pt_faculty_education_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.pt_faculty(id) ON DELETE CASCADE;


--
-- Name: pt_faculty_education pt_faculty_education_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_education
    ADD CONSTRAINT pt_faculty_education_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_faculty_education pt_faculty_education_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty_education
    ADD CONSTRAINT pt_faculty_education_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.pt_academic_programs(id);


--
-- Name: pt_faculty pt_faculty_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty
    ADD CONSTRAINT pt_faculty_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_faculty pt_faculty_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_faculty
    ADD CONSTRAINT pt_faculty_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.pt_school(id);


--
-- Name: pt_institute pt_institution_parent_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_institute
    ADD CONSTRAINT pt_institution_parent_institution_id_fkey FOREIGN KEY (parent_institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_people pt_people_program_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_people
    ADD CONSTRAINT pt_people_program_fkey FOREIGN KEY (phd_program_id) REFERENCES public.pt_academic_programs(id);


--
-- Name: pt_school pt_school_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_school
    ADD CONSTRAINT pt_school_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.pt_institute(id);


--
-- Name: pt_institute pt_university_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_institute
    ADD CONSTRAINT pt_university_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.pt_country(id);


--
-- Name: user_profiles user_profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_stats user_stats_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: pt_education Admin write access to pt_education; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin write access to pt_education" ON public.pt_education USING (public.check_is_admin());


--
-- Name: post_votes Admins can view votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view votes" ON public.post_votes FOR SELECT USING (public.check_is_admin());


--
-- Name: pt_education Allow read access to pt_education; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow read access to pt_education" ON public.pt_education FOR SELECT USING (true);


--
-- Name: forum_posts Anyone can view non-deleted posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view non-deleted posts" ON public.forum_posts FOR SELECT USING (((COALESCE(is_deleted, false) = false) OR public.check_is_admin()));


--
-- Name: poll_options Anyone can view poll options; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view poll options" ON public.poll_options FOR SELECT USING (true);


--
-- Name: poll_votes Anyone can view poll votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view poll votes" ON public.poll_votes FOR SELECT USING (true);


--
-- Name: polls Anyone can view polls; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view polls" ON public.polls FOR SELECT USING (true);


--
-- Name: forum_threads Anyone can view threads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view threads" ON public.forum_threads FOR SELECT USING (true);


--
-- Name: bookmarks Non-blocked users can add bookmarks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can add bookmarks" ON public.bookmarks FOR INSERT WITH CHECK (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: poll_votes Non-blocked users can add own poll votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can add own poll votes" ON public.poll_votes FOR INSERT WITH CHECK (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: ignored_users Non-blocked users can add to ignored list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can add to ignored list" ON public.ignored_users FOR INSERT WITH CHECK (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: post_votes Non-blocked users can change own vote; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can change own vote" ON public.post_votes FOR UPDATE USING (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: poll_options Non-blocked users can create poll options; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can create poll options" ON public.poll_options FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND public.is_not_blocked()));


--
-- Name: polls Non-blocked users can create polls; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can create polls" ON public.polls FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND public.is_not_blocked()));


--
-- Name: forum_posts Non-blocked users can create posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can create posts" ON public.forum_posts FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND public.is_not_blocked()));


--
-- Name: forum_threads Non-blocked users can create threads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can create threads" ON public.forum_threads FOR INSERT WITH CHECK (((auth.uid() IS NOT NULL) AND public.is_not_blocked()));


--
-- Name: ignored_users Non-blocked users can remove from ignored list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can remove from ignored list" ON public.ignored_users FOR DELETE USING (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: bookmarks Non-blocked users can remove own bookmarks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can remove own bookmarks" ON public.bookmarks FOR DELETE USING (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: poll_votes Non-blocked users can remove own poll votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can remove own poll votes" ON public.poll_votes FOR DELETE USING (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: post_votes Non-blocked users can remove own vote; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can remove own vote" ON public.post_votes FOR DELETE USING (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: feedback_messages Non-blocked users can send messages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can send messages" ON public.feedback_messages FOR INSERT TO authenticated WITH CHECK (((user_id = auth.uid()) AND public.is_not_blocked()));


--
-- Name: post_votes Non-blocked users can vote; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Non-blocked users can vote" ON public.post_votes FOR INSERT WITH CHECK (((auth.uid() = user_id) AND public.is_not_blocked()));


--
-- Name: feedback_messages Recipients can mark messages as read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Recipients can mark messages as read" ON public.feedback_messages FOR UPDATE TO authenticated USING (((recipient_id = auth.uid()) OR public.check_is_admin())) WITH CHECK (((recipient_id = auth.uid()) OR public.check_is_admin()));


--
-- Name: notifications Users can delete own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own notifications" ON public.notifications FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: user_profiles Users can insert own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own profile" ON public.user_profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: notifications Users can update own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: bookmarks Users can view own bookmarks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own bookmarks" ON public.bookmarks FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: ignored_users Users can view own ignored list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own ignored list" ON public.ignored_users FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: notifications Users can view own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_profiles Users can view own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own profile" ON public.user_profiles FOR SELECT USING (((auth.uid() = id) OR public.check_is_admin()));


--
-- Name: feedback_messages Users can view their conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their conversations" ON public.feedback_messages FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (recipient_id = auth.uid()) OR public.check_is_admin()));


--
-- Name: bookmarks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

--
-- Name: feedback_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feedback_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: forum_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: forum_threads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.forum_threads ENABLE ROW LEVEL SECURITY;

--
-- Name: ignored_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ignored_users ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: poll_options; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;

--
-- Name: poll_votes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: polls; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;

--
-- Name: post_votes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: pt_education; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pt_education ENABLE ROW LEVEL SECURITY;

--
-- Name: user_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
