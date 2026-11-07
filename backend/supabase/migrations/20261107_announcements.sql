-- Independent of notification delivery. Drafts do not send or display anything.
BEGIN;
CREATE TABLE public.announcement_campaigns (
 id text PRIMARY KEY CHECK (id ~ '^[a-z0-9][a-z0-9_-]{0,79}$'),
 category text NOT NULL CHECK (category IN ('founders_access','product_update','founders')),
 design text NOT NULL CHECK (design IN ('access','pricing','whats_new','message')),
 status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
 title text NOT NULL CHECK (length(title) BETWEEN 1 AND 160),
 body text CHECK (length(body)<=2000),
 cta text NOT NULL DEFAULT 'Got it' CHECK (cta IN ('Got it','Try it')),
 action text NOT NULL DEFAULT 'dismiss' CHECK (action IN ('dismiss','capture')),
 platforms text[] NOT NULL DEFAULT ARRAY['ios'],
 min_client integer NOT NULL DEFAULT 1 CHECK (min_client>0),
 starts_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz,
 audience text NOT NULL DEFAULT 'all' CHECK (audience IN ('all','new','existing')),
 audience_cutoff timestamptz NOT NULL DEFAULT now(),
 rollout_percent integer NOT NULL DEFAULT 100 CHECK (rollout_percent BETWEEN 0 AND 100),
 requires_pilot boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (expires_at IS NULL OR expires_at>starts_at),
 CHECK ((action='capture' AND cta='Try it' AND design='whats_new') OR (action='dismiss' AND cta='Got it')),
 CHECK (design NOT IN ('access','pricing') OR requires_pilot)
);
CREATE TABLE public.user_announcement_state (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 campaign_id text NOT NULL REFERENCES public.announcement_campaigns(id),
 session_id uuid,
 claimed_at timestamptz NOT NULL DEFAULT now(),
 shown_at timestamptz,
 dismissed_at timestamptz,
 acknowledged_at timestamptz,
 clicked_at timestamptz,
 legacy boolean NOT NULL DEFAULT false,
 PRIMARY KEY(user_id,campaign_id),
 UNIQUE(user_id,session_id)
);
CREATE INDEX announcement_frequency ON public.user_announcement_state(user_id,claimed_at DESC) WHERE NOT legacy;
ALTER TABLE public.announcement_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_announcement_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.announcement_campaigns,public.user_announcement_state FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.announcement_campaigns,public.user_announcement_state TO service_role;
GRANT SELECT ON public.user_announcement_state TO authenticated;
CREATE POLICY announcement_receipts_own ON public.user_announcement_state FOR SELECT TO authenticated
 USING (user_id=auth.uid() AND coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb->>'api_key_id' IS NULL);
-- Campaigns are never directly client-readable. The API returns only the selected
-- eligible campaign; unpublished content and targeting remain private.
CREATE FUNCTION public.findez_claim_announcement(
 p_user uuid,p_session uuid,p_platform text,p_client integer,p_pilot boolean,p_legacy_seen boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE selected public.announcement_campaigns; account_created timestamptz; previous_intro boolean;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('announcement:'||p_user::text,0));
 SELECT created_at,coalesce(raw_user_meta_data->>'findez_plan_intro_version','0')='1'
 INTO account_created,previous_intro FROM auth.users WHERE id=p_user;
 IF account_created IS NULL THEN RETURN NULL; END IF;
 -- Only the legacy welcome campaign is suppressed, never future campaigns.
 IF previous_intro OR p_legacy_seen THEN
  INSERT INTO public.user_announcement_state(user_id,campaign_id,dismissed_at,legacy)
   SELECT p_user,id,now(),true FROM public.announcement_campaigns WHERE id='founders-access-v1'
   ON CONFLICT DO NOTHING;
 END IF;
 -- Claims count conservatively even if the process dies before rendering. This
 -- avoids replay on another device after a lost response or an interrupted launch.
 IF EXISTS(SELECT 1 FROM public.user_announcement_state WHERE user_id=p_user AND session_id=p_session)
 OR EXISTS(SELECT 1 FROM public.user_announcement_state WHERE user_id=p_user AND NOT legacy AND claimed_at>now()-interval '7 days')
 THEN RETURN NULL; END IF;
 SELECT c.* INTO selected FROM public.announcement_campaigns c
 WHERE c.status='published' AND c.starts_at<=now() AND (c.expires_at IS NULL OR c.expires_at>now())
 AND p_platform=ANY(c.platforms) AND c.min_client<=p_client
 AND (NOT c.requires_pilot OR p_pilot)
 AND (c.audience='all' OR (c.audience='new' AND account_created>=c.audience_cutoff) OR (c.audience='existing' AND account_created<c.audience_cutoff))
 AND (('x'||substr(md5(p_user::text||':'||c.id),1,8))::bit(32)::bigint%100)<c.rollout_percent
 AND NOT EXISTS(SELECT 1 FROM public.user_announcement_state s WHERE s.user_id=p_user AND s.campaign_id=c.id)
 AND (c.category<>'founders' OR NOT EXISTS(
  SELECT 1 FROM public.user_announcement_state s JOIN public.announcement_campaigns prior ON prior.id=s.campaign_id
  WHERE s.user_id=p_user AND NOT s.legacy AND prior.category='founders' AND s.claimed_at>now()-interval '30 days'))
 ORDER BY CASE c.category WHEN 'founders_access' THEN 0 WHEN 'product_update' THEN 1 ELSE 2 END,c.starts_at,c.id LIMIT 1;
 IF selected.id IS NULL THEN RETURN NULL; END IF;
 INSERT INTO public.user_announcement_state(user_id,campaign_id,session_id) VALUES(p_user,selected.id,p_session);
 RETURN jsonb_build_object('id',selected.id,'category',selected.category,'design',selected.design,
  'title',selected.title,'body',selected.body,'cta',selected.cta,'action',selected.action,'expires_at',selected.expires_at);
END $$;
CREATE FUNCTION public.findez_announcement_receipt(p_user uuid,p_campaign text,p_event text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF p_event NOT IN ('shown','dismissed','acknowledged','clicked') THEN RETURN false; END IF;
 UPDATE public.user_announcement_state SET
  shown_at=CASE WHEN p_event='shown' THEN coalesce(shown_at,now()) ELSE shown_at END,
  dismissed_at=CASE WHEN p_event IN ('dismissed','acknowledged','clicked') THEN coalesce(dismissed_at,now()) ELSE dismissed_at END,
  acknowledged_at=CASE WHEN p_event='acknowledged' THEN coalesce(acknowledged_at,now()) ELSE acknowledged_at END,
  clicked_at=CASE WHEN p_event='clicked' THEN coalesce(clicked_at,now()) ELSE clicked_at END
 WHERE user_id=p_user AND campaign_id=p_campaign;
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.findez_claim_announcement(uuid,uuid,text,integer,boolean,boolean),public.findez_announcement_receipt(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_claim_announcement(uuid,uuid,text,integer,boolean,boolean),public.findez_announcement_receipt(uuid,text,text) TO service_role;
INSERT INTO public.announcement_campaigns(id,category,design,title,body,requires_pilot) VALUES
 ('founders-access-v1','founders_access','access','You''re in early.',NULL,true),
 ('pricing-note-v1','product_update','pricing','FindEZ is free to explore.','Paid plans may come later. Here''s what stays free.',true);
INSERT INTO public.announcement_campaigns(id,category,design,title,cta,action) VALUES
 ('auto-extract-v1','product_update','whats_new','Photos scan on their own.','Try it','capture');
-- Founders milestones are deliberately not fabricated or seeded.
COMMIT;
