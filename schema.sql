--
-- PostgreSQL database dump
--

\restrict eYMat23mhekKVw19FvvjdqnRjGgWLldkt0x8wYrh08kuDppM6dWv4uqtaDNHe0e

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: school_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.school_type AS ENUM (
    'degree_granting',
    'continuing_education',
    'non_degree',
    'administrative'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


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
-- Name: deduplicate_faculty(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deduplicate_faculty() RETURNS TABLE(merged_count integer, deleted_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  dup_record RECORD;
  keep_id uuid;
  delete_ids uuid[];
  total_merged int := 0;
  total_deleted int := 0;
BEGIN
  -- Find all duplicates (same name + same PhD program + same year + same edu institution)
  FOR dup_record IN
    WITH faculty_with_phd AS (
      SELECT 
        f.id as faculty_id,
        f.name,
        fe.program_id,
        fe.year,
        fe.institution_id as edu_institution_id,
        -- Score based on data completeness
        (CASE WHEN f.profile_url IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN f.institution_id IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN f.department_id IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN f.official_email IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN f.linkedin IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN f.google_scholar IS NOT NULL THEN 1 ELSE 0 END) as completeness_score
      FROM pt_faculty f
      JOIN pt_faculty_education fe ON f.id = fe.faculty_id
      WHERE LOWER(fe.degree) = 'phd'
    ),
    duplicates AS (
      SELECT 
        name,
        program_id,
        year,
        edu_institution_id,
        ARRAY_AGG(faculty_id ORDER BY completeness_score DESC, faculty_id) as faculty_ids
      FROM faculty_with_phd
      GROUP BY name, program_id, year, edu_institution_id
      HAVING COUNT(DISTINCT faculty_id) > 1
    )
    SELECT * FROM duplicates
  LOOP
    -- Keep the first one (highest completeness score)
    keep_id := dup_record.faculty_ids[1];
    delete_ids := dup_record.faculty_ids[2:];
    
    -- Move career records to kept faculty
    UPDATE pt_faculty_career
    SET faculty_id = keep_id
    WHERE faculty_id = ANY(delete_ids)
    AND NOT EXISTS (
      SELECT 1 FROM pt_faculty_career c2 
      WHERE c2.faculty_id = keep_id 
      AND c2.institution_id IS NOT DISTINCT FROM pt_faculty_career.institution_id
      AND c2.designation IS NOT DISTINCT FROM pt_faculty_career.designation
    );
    
    -- Delete duplicate career records that would cause conflicts
    DELETE FROM pt_faculty_career
    WHERE faculty_id = ANY(delete_ids);
    
    -- Move education records to kept faculty (avoid duplicates)
    UPDATE pt_faculty_education
    SET faculty_id = keep_id
    WHERE faculty_id = ANY(delete_ids)
    AND NOT EXISTS (
      SELECT 1 FROM pt_faculty_education e2 
      WHERE e2.faculty_id = keep_id 
      AND e2.program_id IS NOT DISTINCT FROM pt_faculty_education.program_id
      AND e2.year IS NOT DISTINCT FROM pt_faculty_education.year
    );
    
    -- Delete duplicate education records
    DELETE FROM pt_faculty_education
    WHERE faculty_id = ANY(delete_ids);
    
    -- Delete duplicate faculty records
    DELETE FROM pt_faculty
    WHERE id = ANY(delete_ids);
    
    total_merged := total_merged + 1;
    total_deleted := total_deleted + array_length(delete_ids, 1);
  END LOOP;
  
  merged_count := total_merged;
  deleted_count := total_deleted;
  RETURN NEXT;
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
  result json;
BEGIN
  SELECT json_build_object(
    'degrees', json_build_array('PhD'),
    'programs', (
      SELECT json_agg(DISTINCT prog ORDER BY prog)
      FROM (
        SELECT INITCAP(COALESCE(ap.alias, e.field)) as prog
        FROM pt_faculty_education e
        LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
        WHERE COALESCE(ap.alias, e.field) IS NOT NULL 
          AND TRIM(COALESCE(ap.alias, e.field)) != '' 
          AND LENGTH(TRIM(COALESCE(ap.alias, e.field))) > 2
          AND LOWER(e.degree) = 'phd'
      ) sub
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
        'option_text', po.option_text,
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
  SELECT DISTINCT INITCAP(COALESCE(ap.alias, e.field)) as program
  FROM pt_faculty_education e
  JOIN pt_faculty_career c ON c.faculty_id = e.faculty_id
  LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
  WHERE LOWER(e.degree) = 'phd'
    AND (e.field IS NOT NULL OR ap.alias IS NOT NULL)
    AND (c.designation IS NOT NULL OR c.institution_id IS NOT NULL)
    AND (p_from_year IS NULL OR e.year >= p_from_year)
    AND (p_to_year IS NULL OR e.year <= p_to_year)
  ORDER BY INITCAP(COALESCE(ap.alias, e.field));
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
  LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
  WHERE LOWER(e.degree) = 'phd'
    AND LOWER(COALESCE(ap.alias, e.field)) = LOWER(p_program)
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

  RETURN (SELECT COUNT(*) FROM feedback_messages WHERE recipient_id = p_user_id AND is_read = FALSE);
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
-- Name: pt_faculty_career_lowercase_designation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pt_faculty_career_lowercase_designation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.designation IS NOT NULL THEN
    NEW.designation := LOWER(NEW.designation);
  END IF;
  RETURN NEW;
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
-- Name: reverse_search_placements(text, text, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_search_placements(p_program text DEFAULT NULL::text, p_placement_univ text DEFAULT NULL::text, p_from_year integer DEFAULT NULL::integer, p_to_year integer DEFAULT NULL::integer, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0) RETURNS TABLE(id text, name text, phd_university text, role text, year integer, placement_univ text, program text, degree text, discipline text, total_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH phd_grads AS (
    SELECT
      f.id as faculty_id,
      INITCAP(COALESCE(f.updated_name, f.name)) as name,
      COALESCE(ap.program_name, e.field) as program,
      COALESCE(ap.alias, e.field) as alias,
      e.degree,
      e.year as phd_year,
      i.official_name as phd_university
    FROM pt_faculty f
    JOIN pt_faculty_education e ON e.faculty_id = f.id AND LOWER(e.degree) = 'phd'
    LEFT JOIN pt_institute i ON e.institution_id = i.id
    LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
    WHERE
      (p_program IS NULL OR LOWER(COALESCE(ap.alias, e.field)) = LOWER(p_program))
      AND (p_from_year IS NULL OR e.year >= p_from_year)
      AND (p_to_year IS NULL OR e.year <= p_to_year)
  ),
  first_career AS (
    SELECT DISTINCT ON (c.faculty_id)
      c.faculty_id,
      COALESCE(pi.official_name, INITCAP(c.institution_name)) as placement_univ,
      INITCAP(COALESCE(c.updated_designation, c.designation)) as role,
      c.year as placement_year
    FROM pt_faculty_career c
    JOIN phd_grads g ON c.faculty_id = g.faculty_id
    LEFT JOIN pt_institute pi ON c.institution_id = pi.id
    WHERE (c.institution_name IS NOT NULL OR c.institution_id IS NOT NULL OR c.designation IS NOT NULL)
      AND (p_placement_univ IS NULL OR LOWER(COALESCE(pi.lowercase_name, c.institution_name)) LIKE '%' || LOWER(p_placement_univ) || '%')
    ORDER BY c.faculty_id, c.year ASC NULLS LAST
  ),
  filtered AS (
    SELECT
      g.faculty_id::text as id,
      g.name,
      g.phd_university,
      fc.role,
      g.phd_year as year,
      fc.placement_univ,
      g.program,
      g.degree,
      g.alias as discipline
    FROM phd_grads g
    JOIN first_career fc ON fc.faculty_id = g.faculty_id
  ),
  counted AS (
    SELECT COUNT(*) as cnt FROM filtered
  )
  SELECT
    f.id,
    f.name,
    f.phd_university,
    f.role,
    f.year,
    f.placement_univ,
    INITCAP(f.program) as program,
    f.degree,
    INITCAP(f.discipline) as discipline,
    c.cnt as total_count
  FROM filtered f, counted c
  ORDER BY f.year DESC NULLS LAST, f.name
  LIMIT p_limit
  OFFSET p_offset;
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
      INITCAP(COALESCE(f.updated_name, f.name)) as name,
      INITCAP(COALESCE(ap.program_name, e.field)) as program,
      INITCAP(COALESCE(ap.alias, e.field)) as alias,
      e.degree,
      e.year as phd_year,
      INITCAP(i.english_name) as phd_university
    FROM pt_faculty f
    JOIN pt_faculty_education e ON e.faculty_id = f.id AND LOWER(e.degree) = 'phd'
    LEFT JOIN pt_institute i ON e.institution_id = i.id
    LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
    WHERE
      (p_program IS NULL OR LOWER(COALESCE(ap.alias, e.field)) = LOWER(p_program))
      AND (p_from_year IS NULL OR e.year >= p_from_year)
      AND (p_to_year IS NULL OR e.year <= p_to_year)
  ),
  first_career AS (
    SELECT DISTINCT ON (c.faculty_id)
      c.faculty_id,
      INITCAP(COALESCE(
        school_univ.english_name,
        matched_univ.english_name,
        pi.english_name,
        c.institution_name
      )) as placement_univ,
      INITCAP(COALESCE(c.updated_designation, c.designation)) as role,
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
      g.alias as discipline
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
      INITCAP(COALESCE(f.updated_name, f.name)) as name,
      INITCAP(COALESCE(ap.program_name, e.field)) as program,
      INITCAP(COALESCE(ap.alias, e.field)) as alias,
      e.degree,
      e.year as phd_year,
      INITCAP(i.english_name) as phd_university
    FROM pt_faculty f
    JOIN pt_faculty_education e ON e.faculty_id = f.id AND LOWER(e.degree) = 'phd'
    LEFT JOIN pt_academic_programs ap ON e.program_id = ap.id
    LEFT JOIN pt_institute i ON e.institution_id = i.id
    WHERE
      (p_program IS NULL OR LOWER(COALESCE(ap.alias, e.field)) = LOWER(p_program))
      AND (p_university IS NULL OR LOWER(i.english_name) = LOWER(p_university))
      AND (p_from_year IS NULL OR e.year >= p_from_year)
      AND (p_to_year IS NULL OR e.year <= p_to_year)
  ),
  first_career AS (
    SELECT DISTINCT ON (c.faculty_id)
      c.faculty_id,
      INITCAP(COALESCE(
        school_univ.english_name,
        matched_univ.english_name,
        pi.english_name,
        c.institution_name
      )) as placement_univ,
      INITCAP(COALESCE(c.updated_designation, c.designation)) as role,
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
      g.alias as discipline
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


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_;

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS SETOF realtime.wal_rls
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: add_prefixes(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.add_prefixes(_bucket_id text, _name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    prefixes text[];
BEGIN
    prefixes := "storage"."get_prefixes"("_name");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, "_bucket_id" ON CONFLICT DO NOTHING;
    END IF;
END;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: delete_leaf_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


--
-- Name: delete_prefix(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix(_bucket_id text, _name text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name") + 1
          AND "prefixes"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM "storage"."objects"
        WHERE "objects"."bucket_id" = "_bucket_id"
          AND "storage"."get_level"("objects"."name") = "storage"."get_level"("_name") + 1
          AND "objects"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name")
          AND "prefixes"."name" = "_name";
        RETURN true;
    END IF;
END;
$$;


--
-- Name: delete_prefix_hierarchy_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix_hierarchy_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix text;
BEGIN
    prefix := "storage"."get_prefix"(OLD."name");

    IF coalesce(prefix, '') != '' THEN
        PERFORM "storage"."delete_prefix"(OLD."bucket_id", prefix);
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_level(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_level(name text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


--
-- Name: get_prefix(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefix(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


--
-- Name: get_prefixes(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefixes(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE "C" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                name COLLATE "C" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE "C" ASC) as e order by name COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$_$;


--
-- Name: lock_top_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.lock_top_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$$;


--
-- Name: objects_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: objects_insert_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_insert_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    NEW.level := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: objects_update_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: objects_update_level_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_level_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Set the new level
        NEW."level" := "storage"."get_level"(NEW."name");
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: objects_update_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Retrieve old prefixes
        old_prefixes := "storage"."get_prefixes"(OLD."name");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM "storage"."objects"
                 WHERE "bucket_id" = OLD."bucket_id"
                   AND "name" <> OLD."name"
                   AND "name" LIKE (prefix || '%')
             )
         )
        DELETE FROM "storage"."prefixes" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    END IF;
    -- Set the new level
    NEW."level" := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: prefixes_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: prefixes_insert_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    RETURN NEW;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql
    AS $$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$$;


--
-- Name: search_legacy_v1(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v1_optimised(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v1_optimised(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE "C") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE "C" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE "C" %s $5)', cursor_op);
        sort_expr := format('name COLLATE "C" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$_$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text NOT NULL,
    code_challenge_method auth.code_challenge_method NOT NULL,
    code_challenge text NOT NULL,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'stores metadata for pkce logins';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


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
-- Name: copy_pt_career; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.copy_pt_career (
    id text,
    person_id text,
    year integer,
    designation text,
    institution_id text,
    school_id text,
    department_id text,
    source_url text,
    updated_at timestamp with time zone
);


--
-- Name: copy_pt_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.copy_pt_people (
    id text,
    phd_program_id text,
    year integer,
    name text,
    updated_at timestamp with time zone,
    initial_designation text,
    current_designation text,
    phd_advisor text,
    phd_dissertation_title text,
    phd_thesis_committee text,
    linkedin_url text,
    google_scholar_url text,
    initial_institution_id text,
    initial_school_id text,
    initial_department_id text,
    current_institution_id text,
    current_school_id text,
    current_department_id text,
    email text,
    source character varying(50),
    source_url text
);


--
-- Name: debug_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debug_log (
    id integer NOT NULL,
    message text,
    created_at timestamp with time zone DEFAULT now()
);


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
-- Name: migration_2023_phd_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migration_2023_phd_map (
    people_id text NOT NULL,
    faculty_id uuid,
    is_primary boolean DEFAULT false
);


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
    department_id text,
    profile_url text,
    cv_url text,
    personal_url text,
    google_scholar text,
    linkedin text,
    personal_phone text,
    official_phone text,
    personal_email text,
    official_email text,
    updated_at timestamp with time zone DEFAULT now(),
    gender text,
    designation text DEFAULT ''::text,
    academia_edu text,
    updated_name text
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
    institution_name text,
    updated_designation text
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
    parsing_comment text DEFAULT ''::text,
    lowercase_name text,
    official_name text,
    english_name text,
    abbreviation text
);


--
-- Name: TABLE pt_institute; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.pt_institute IS 'Stores institutions (universities, colleges, companies, etc.)';


--
-- Name: COLUMN pt_institute.parent_institution_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.parent_institution_id IS 'Parent institution ID for hierarchical relationships (e.g., lab -> university, department -> university)';


--
-- Name: COLUMN pt_institute.lowercase_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.lowercase_name IS 'Lowercase version of the institution name, used for matching and comparisons';


--
-- Name: COLUMN pt_institute.official_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.official_name IS 'Official name of the institution as it should be displayed to users';


--
-- Name: COLUMN pt_institute.english_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.english_name IS 'English translation of the official name for foreign institutions whose official name is not in English';


--
-- Name: COLUMN pt_institute.abbreviation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pt_institute.abbreviation IS 'Official abbreviation of the institution in English';


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
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb,
    level integer
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: prefixes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.prefixes (
    bucket_id text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    level integer GENERATED ALWAYS AS (storage.get_level(name)) STORED NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: bookmarks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN id SET DEFAULT nextval('public.bookmarks_id_seq'::regclass);


--
-- Name: debug_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debug_log ALTER COLUMN id SET DEFAULT nextval('public.debug_log_id_seq'::regclass);


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
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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
-- Name: debug_log debug_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debug_log
    ADD CONSTRAINT debug_log_pkey PRIMARY KEY (id);


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
-- Name: migration_2023_phd_map migration_2023_phd_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migration_2023_phd_map
    ADD CONSTRAINT migration_2023_phd_map_pkey PRIMARY KEY (people_id);


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
-- Name: pt_institute pt_institute_lowercase_name_country_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pt_institute
    ADD CONSTRAINT pt_institute_lowercase_name_country_id_unique UNIQUE (lowercase_name, country_id);


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
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: prefixes prefixes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT prefixes_pkey PRIMARY KEY (bucket_id, level, name);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


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
-- Name: idx_pt_faculty_career_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_faculty_career_unique ON public.pt_faculty_career USING btree (faculty_id, COALESCE(year, 0), COALESCE(designation, ''::text), COALESCE(institution_id, ''::text));


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
-- Name: idx_pt_faculty_education_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pt_faculty_education_unique ON public.pt_faculty_education USING btree (faculty_id, COALESCE(degree, ''::text), COALESCE(year, 0), COALESCE(program_id, ''::text));


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
-- Name: user_profiles_username_lower_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_profiles_username_lower_idx ON public.user_profiles USING btree (lower(username));


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_key ON realtime.subscription USING btree (subscription_id, entity, filters);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_name_bucket_level_unique; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_name_bucket_level_unique ON storage.objects USING btree (name COLLATE "C", bucket_id, level);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_lower_name ON storage.objects USING btree ((path_tokens[level]), lower(name) text_pattern_ops, bucket_id, level);


--
-- Name: idx_prefixes_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_prefixes_lower_name ON storage.prefixes USING btree (bucket_id, level, ((string_to_array(name, '/'::text))[level]), lower(name) text_pattern_ops);


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: objects_bucket_id_level_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_bucket_id_level_idx ON storage.objects USING btree (bucket_id, level, name COLLATE "C");


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


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
-- Name: pt_faculty_career pt_faculty_career_lowercase_designation_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pt_faculty_career_lowercase_designation_trigger BEFORE INSERT OR UPDATE ON public.pt_faculty_career FOR EACH ROW EXECUTE FUNCTION public.pt_faculty_career_lowercase_designation();


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
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: objects objects_delete_delete_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects objects_insert_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();


--
-- Name: objects objects_update_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();


--
-- Name: prefixes prefixes_create_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();


--
-- Name: prefixes prefixes_delete_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


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
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: prefixes prefixes_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT "prefixes_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

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

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: prefixes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.prefixes ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict eYMat23mhekKVw19FvvjdqnRjGgWLldkt0x8wYrh08kuDppM6dWv4uqtaDNHe0e
