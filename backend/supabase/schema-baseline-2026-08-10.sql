--
-- PostgreSQL database dump
--

\restrict RwLUfn0j1ZtAeFukIM5dKusH7hS9OgvmujfGEQBqcS2gY2fogxRjlCalfa38hDx

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10 (Ubuntu 17.10-1.pgdg24.04+1)

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, is_pro, created_at)
  VALUES (new.id, false, now())
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;


--
-- Name: increment_chat_usage(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_chat_usage(p_user_id uuid, p_period text) RETURNS TABLE(chats_used integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    insert into public.usage_counters (user_id, period, chats_used, scans_used, scans_today, today)
    values (p_user_id, p_period, 1, 0, 0, current_date)
    on conflict (user_id, period)
    do update set
        chats_used = public.usage_counters.chats_used + 1,
        updated_at = now()
    returning public.usage_counters.chats_used;
$$;


--
-- Name: increment_scan_usage(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_scan_usage(p_user_id uuid, p_period text) RETURNS TABLE(scans_used integer, scans_today integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    insert into public.usage_counters (user_id, period, chats_used, scans_used, scans_today, today)
    values (p_user_id, p_period, 0, 1, 1, current_date)
    on conflict (user_id, period)
    do update set
        scans_used  = public.usage_counters.scans_used + 1,
        scans_today = case
            when public.usage_counters.today = current_date
            then public.usage_counters.scans_today + 1
            else 1
        end,
        today       = current_date,
        updated_at  = now()
    returning public.usage_counters.scans_used, public.usage_counters.scans_today;
$$;


--
-- Name: increment_usage_count(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_usage_count(p_user_id uuid, p_feature text, p_period text) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    insert into public.usage_limits (user_id, feature, count, period, updated_at)
    values (p_user_id, p_feature, 1, p_period, now())
    on conflict (user_id, feature, period)
    do update set
        count      = public.usage_limits.count + 1,
        updated_at = now()
    returning count;
$$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: update_conversation_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_conversation_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE conversations SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_log (
    activity_id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    event_type text,
    raw_event jsonb,
    summary text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: checkouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkouts (
    checkout_id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    item_id uuid NOT NULL,
    checked_out_by text NOT NULL,
    checked_out_at timestamp with time zone DEFAULT now(),
    due_back_at timestamp with time zone,
    returned_at timestamp with time zone,
    notes text,
    is_active boolean DEFAULT true,
    space_name text,
    quantity integer DEFAULT 1 NOT NULL
);


--
-- Name: conversation_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    question text NOT NULL,
    answer text NOT NULL,
    space_id text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: conversation_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_sessions (
    user_id uuid NOT NULL,
    history jsonb DEFAULT '[]'::jsonb NOT NULL,
    last_item_name text,
    last_user_message text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text DEFAULT 'New Chat'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    document_id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    filename text NOT NULL,
    file_type text NOT NULL,
    mime_type text NOT NULL,
    storage_path text NOT NULL,
    size_bytes bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    url text,
    ai_access_granted boolean DEFAULT false NOT NULL,
    ai_access_granted_at timestamp with time zone,
    extracted_text text,
    item_id uuid,
    display_name text
);


--
-- Name: item_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_events (
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    item_id uuid NOT NULL,
    user_id uuid NOT NULL,
    event_type text NOT NULL,
    content text,
    quantity_delta integer,
    image_url text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT item_events_event_type_check CHECK ((event_type = ANY (ARRAY['usage'::text, 'note'::text, 'failure'::text, 'success'::text, 'restock'::text, 'photo'::text])))
);


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    item_id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    category text NOT NULL,
    quantity integer NOT NULL,
    location text NOT NULL,
    image_url text,
    barcode text,
    purchase_source text,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    user_id uuid NOT NULL,
    subcategory text,
    brand text,
    part_number text,
    tags text[],
    confidence double precision,
    space_id uuid
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);


--
-- Name: parts_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parts_catalog (
    catalog_id uuid DEFAULT gen_random_uuid() NOT NULL,
    barcode text,
    canonical_name text NOT NULL,
    aliases text[],
    brand text,
    category text,
    subcategory text,
    part_number text,
    description text,
    image_urls text[],
    source text,
    confirmation_count integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    created_at timestamp with time zone DEFAULT now(),
    is_pro boolean DEFAULT false,
    pending_deletion boolean DEFAULT false,
    deletion_scheduled_at timestamp with time zone,
    plan text DEFAULT 'free'::text,
    rc_customer_id text,
    pro_expires_at timestamp with time zone,
    stripe_customer_id text,
    stripe_subscription_id text,
    display_name text,
    contact_email text,
    avatar_color text DEFAULT '#636366'::text,
    tier text DEFAULT 'free'::text NOT NULL,
    subscription_plan text,
    subscription_renews_at timestamp with time zone,
    CONSTRAINT profiles_tier_check CHECK ((tier = ANY (ARRAY['free'::text, 'pro'::text, 'team_member'::text])))
);


--
-- Name: query_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.query_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    query_text text NOT NULL,
    query_type text,
    space_id text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: spaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_members (
    member_id uuid DEFAULT gen_random_uuid() NOT NULL,
    share_id uuid,
    member_user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


--
-- Name: team_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_shares (
    share_id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_user_id uuid NOT NULL,
    share_code text NOT NULL,
    share_name text,
    permission text DEFAULT 'view'::text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    plan text,
    plan_expires_at timestamp with time zone
);


--
-- Name: usage_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_counters (
    user_id uuid NOT NULL,
    period text NOT NULL,
    chats_used integer DEFAULT 0 NOT NULL,
    scans_used integer DEFAULT 0 NOT NULL,
    scans_today integer DEFAULT 0 NOT NULL,
    today date DEFAULT CURRENT_DATE NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: usage_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_limits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    feature text NOT NULL,
    count integer DEFAULT 0,
    period text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_memory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_memory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    key text NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_plan (
    user_id uuid NOT NULL,
    plan text DEFAULT 'free'::text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: activity_log activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_pkey PRIMARY KEY (activity_id);


--
-- Name: checkouts checkouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkouts
    ADD CONSTRAINT checkouts_pkey PRIMARY KEY (checkout_id);


--
-- Name: conversation_history conversation_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_history
    ADD CONSTRAINT conversation_history_pkey PRIMARY KEY (id);


--
-- Name: conversation_sessions conversation_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_sessions
    ADD CONSTRAINT conversation_sessions_pkey PRIMARY KEY (user_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (document_id);


--
-- Name: item_events item_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_events
    ADD CONSTRAINT item_events_pkey PRIMARY KEY (event_id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (item_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: parts_catalog parts_catalog_barcode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts_catalog
    ADD CONSTRAINT parts_catalog_barcode_key UNIQUE (barcode);


--
-- Name: parts_catalog parts_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts_catalog
    ADD CONSTRAINT parts_catalog_pkey PRIMARY KEY (catalog_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: query_logs query_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.query_logs
    ADD CONSTRAINT query_logs_pkey PRIMARY KEY (id);


--
-- Name: spaces spaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_pkey PRIMARY KEY (id);


--
-- Name: spaces spaces_user_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_user_id_name_key UNIQUE (user_id, name);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (member_id);


--
-- Name: team_members team_members_share_id_member_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_share_id_member_user_id_key UNIQUE (share_id, member_user_id);


--
-- Name: team_shares team_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_shares
    ADD CONSTRAINT team_shares_pkey PRIMARY KEY (share_id);


--
-- Name: team_shares team_shares_share_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_shares
    ADD CONSTRAINT team_shares_share_code_key UNIQUE (share_code);


--
-- Name: usage_counters usage_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_counters
    ADD CONSTRAINT usage_counters_pkey PRIMARY KEY (user_id, period);


--
-- Name: usage_limits usage_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_pkey PRIMARY KEY (id);


--
-- Name: usage_limits usage_limits_user_feature_period_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_user_feature_period_key UNIQUE (user_id, feature, period);


--
-- Name: usage_limits usage_limits_user_id_feature_period_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_user_id_feature_period_key UNIQUE (user_id, feature, period);


--
-- Name: user_memory user_memory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_memory
    ADD CONSTRAINT user_memory_pkey PRIMARY KEY (id);


--
-- Name: user_memory user_memory_user_id_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_memory
    ADD CONSTRAINT user_memory_user_id_key_key UNIQUE (user_id, key);


--
-- Name: user_plan user_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_plan
    ADD CONSTRAINT user_plan_pkey PRIMARY KEY (user_id);


--
-- Name: checkouts_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkouts_active_idx ON public.checkouts USING btree (is_active) WHERE (is_active = true);


--
-- Name: checkouts_item_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkouts_item_id_idx ON public.checkouts USING btree (item_id);


--
-- Name: checkouts_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkouts_user_id_idx ON public.checkouts USING btree (user_id);


--
-- Name: idx_activity_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_user_created ON public.activity_log USING btree (user_id, created_at DESC);


--
-- Name: idx_conv_history_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conv_history_search ON public.conversation_history USING gin (to_tsvector('english'::regconfig, ((question || ' '::text) || answer)));


--
-- Name: idx_conv_history_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conv_history_user ON public.conversation_history USING btree (user_id, created_at DESC);


--
-- Name: idx_conversations_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_updated_at ON public.conversations USING btree (updated_at DESC);


--
-- Name: idx_conversations_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conversations_user_id ON public.conversations USING btree (user_id);


--
-- Name: idx_documents_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_item_id ON public.documents USING btree (item_id);


--
-- Name: idx_documents_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_user_created ON public.documents USING btree (user_id, created_at DESC);


--
-- Name: idx_item_events_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_events_item_id ON public.item_events USING btree (item_id);


--
-- Name: idx_item_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_events_user_id ON public.item_events USING btree (user_id);


--
-- Name: idx_items_space; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_space ON public.items USING btree (space_id);


--
-- Name: idx_items_user_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_barcode ON public.items USING btree (user_id, barcode);


--
-- Name: idx_items_user_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_category ON public.items USING btree (user_id, category);


--
-- Name: idx_items_user_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_created_at ON public.items USING btree (user_id, created_at DESC);


--
-- Name: idx_items_user_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_name ON public.items USING btree (user_id, name);


--
-- Name: idx_items_user_part_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_part_number ON public.items USING btree (user_id, part_number);


--
-- Name: idx_items_user_subcategory; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_user_subcategory ON public.items USING btree (user_id, subcategory);


--
-- Name: idx_messages_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: idx_spaces_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spaces_user ON public.spaces USING btree (user_id);


--
-- Name: idx_spaces_user_name_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_spaces_user_name_ci ON public.spaces USING btree (user_id, lower(TRIM(BOTH FROM name)));


--
-- Name: messages update_conversation_on_message; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_conversation_on_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_conversation_timestamp();


--
-- Name: checkouts checkouts_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkouts
    ADD CONSTRAINT checkouts_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(item_id) ON DELETE CASCADE;


--
-- Name: checkouts checkouts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkouts
    ADD CONSTRAINT checkouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: conversation_history conversation_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_history
    ADD CONSTRAINT conversation_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: conversation_sessions conversation_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_sessions
    ADD CONSTRAINT conversation_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: documents documents_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(item_id) ON DELETE SET NULL;


--
-- Name: item_events item_events_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_events
    ADD CONSTRAINT item_events_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(item_id) ON DELETE CASCADE;


--
-- Name: items items_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_space_id_fkey FOREIGN KEY (space_id) REFERENCES public.spaces(id) ON DELETE SET NULL;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: query_logs query_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.query_logs
    ADD CONSTRAINT query_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: spaces spaces_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_share_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_share_id_fkey FOREIGN KEY (share_id) REFERENCES public.team_shares(share_id) ON DELETE CASCADE;


--
-- Name: usage_limits usage_limits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_memory user_memory_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_memory
    ADD CONSTRAINT user_memory_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_plan user_plan_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_plan
    ADD CONSTRAINT user_plan_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles Profiles: insert own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Profiles: insert own" ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: profiles Profiles: read own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Profiles: read own" ON public.profiles FOR SELECT USING ((auth.uid() = id));


--
-- Name: profiles Profiles: update own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Profiles: update own" ON public.profiles FOR UPDATE USING ((auth.uid() = id));


--
-- Name: conversation_history Service role full access to conversation_history; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access to conversation_history" ON public.conversation_history USING (true) WITH CHECK (true);


--
-- Name: query_logs Service role full access to query_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access to query_logs" ON public.query_logs USING (true) WITH CHECK (true);


--
-- Name: user_memory Service role full access to user_memory; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access to user_memory" ON public.user_memory USING (true) WITH CHECK (true);


--
-- Name: messages Users can delete messages in own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete messages in own conversations" ON public.messages FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND (conversations.user_id = auth.uid())))));


--
-- Name: conversations Users can delete own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own conversations" ON public.conversations FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: messages Users can insert messages in own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert messages in own conversations" ON public.messages FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND (conversations.user_id = auth.uid())))));


--
-- Name: conversations Users can insert own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own conversations" ON public.conversations FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: item_events Users can insert their own item events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own item events" ON public.item_events FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: conversation_history Users can read own history; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own history" ON public.conversation_history FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_memory Users can read own memory; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own memory" ON public.user_memory FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: item_events Users can read their own item events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read their own item events" ON public.item_events FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: conversations Users can update own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own conversations" ON public.conversations FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: messages Users can view messages in own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view messages in own conversations" ON public.messages FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.conversations
  WHERE ((conversations.id = messages.conversation_id) AND (conversations.user_id = auth.uid())))));


--
-- Name: conversations Users can view own conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own conversations" ON public.conversations FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: conversation_sessions Users own their sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users own their sessions" ON public.conversation_sessions USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: activity_log activity_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY activity_insert_own ON public.activity_log FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: activity_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_log activity_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY activity_select_own ON public.activity_log FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: checkouts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checkouts ENABLE ROW LEVEL SECURITY;

--
-- Name: team_members checkouts_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checkouts_delete_own ON public.team_members FOR DELETE USING ((auth.uid() = member_user_id));


--
-- Name: checkouts checkouts_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checkouts_insert_own ON public.checkouts FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: checkouts checkouts_select_team; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checkouts_select_team ON public.checkouts FOR SELECT USING (((auth.uid() = user_id) OR (user_id IN ( SELECT tm.owner_user_id
   FROM (public.team_shares tm
     JOIN public.team_members tmm ON ((tmm.share_id = tm.share_id)))
  WHERE ((tmm.member_user_id = auth.uid()) AND (tm.is_active = true)))) OR (user_id IN ( SELECT tmm.member_user_id
   FROM (public.team_members tmm
     JOIN public.team_shares ts ON ((ts.share_id = tmm.share_id)))
  WHERE ((ts.owner_user_id = auth.uid()) AND (ts.is_active = true))))));


--
-- Name: checkouts checkouts_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checkouts_update_own ON public.checkouts FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: conversation_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversation_history ENABLE ROW LEVEL SECURITY;

--
-- Name: conversation_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversation_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: documents documents_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documents_delete_own ON public.documents FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: documents documents_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documents_insert_own ON public.documents FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: documents documents_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documents_select_own ON public.documents FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: documents documents_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documents_update_own ON public.documents FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: item_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.item_events ENABLE ROW LEVEL SECURITY;

--
-- Name: items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

--
-- Name: items items_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY items_delete_own ON public.items FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: items items_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY items_insert_own ON public.items FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: items items_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY items_select_own ON public.items FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: items items_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY items_update_own ON public.items FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: team_shares member_view_shares; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY member_view_shares ON public.team_shares FOR SELECT USING ((share_id IN ( SELECT team_members.share_id
   FROM public.team_members
  WHERE (team_members.member_user_id = auth.uid()))));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: team_members own_memberships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_memberships ON public.team_members USING ((member_user_id = auth.uid()));


--
-- Name: team_members owner_see_members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_see_members ON public.team_members USING ((share_id IN ( SELECT team_shares.share_id
   FROM public.team_shares
  WHERE (team_shares.owner_user_id = auth.uid()))));


--
-- Name: team_shares owner_shares; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_shares ON public.team_shares USING ((owner_user_id = auth.uid()));


--
-- Name: parts_catalog; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parts_catalog ENABLE ROW LEVEL SECURITY;

--
-- Name: parts_catalog parts_catalog_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parts_catalog_select_authenticated ON public.parts_catalog FOR SELECT TO authenticated USING (true);


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_team; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_team ON public.profiles FOR SELECT USING (((auth.uid() = id) OR (id IN ( SELECT tm.member_user_id
   FROM (public.team_members tm
     JOIN public.team_shares ts ON ((ts.share_id = tm.share_id)))
  WHERE (ts.owner_user_id = auth.uid()))) OR (id IN ( SELECT ts.owner_user_id
   FROM (public.team_shares ts
     JOIN public.team_members tm ON ((tm.share_id = ts.share_id)))
  WHERE (tm.member_user_id = auth.uid())))));


--
-- Name: query_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.query_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: spaces; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;

--
-- Name: spaces spaces_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY spaces_delete_own ON public.spaces FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: spaces spaces_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY spaces_insert_own ON public.spaces FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: spaces spaces_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY spaces_select_own ON public.spaces FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: spaces spaces_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY spaces_update_own ON public.spaces FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: team_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

--
-- Name: team_shares; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_shares ENABLE ROW LEVEL SECURITY;

--
-- Name: usage_counters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usage_counters ENABLE ROW LEVEL SECURITY;

--
-- Name: usage_limits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usage_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: user_memory; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_memory ENABLE ROW LEVEL SECURITY;

--
-- Name: user_plan; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_plan ENABLE ROW LEVEL SECURITY;

--
-- Name: user_plan users_own_plan; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_own_plan ON public.user_plan USING ((auth.uid() = user_id));


--
-- Name: usage_limits users_own_usage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_own_usage ON public.usage_limits USING ((auth.uid() = user_id));


--
-- PostgreSQL database dump complete
--

\unrestrict RwLUfn0j1ZtAeFukIM5dKusH7hS9OgvmujfGEQBqcS2gY2fogxRjlCalfa38hDx

