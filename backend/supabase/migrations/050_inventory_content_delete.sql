-- Explicit content deletion with durable file cleanup. No records erased on install.
BEGIN;
CREATE TABLE public.app_inventory_deletions (
 inventory_id uuid PRIMARY KEY, actor_id uuid NOT NULL, files jsonb NOT NULL,
 completed boolean NOT NULL DEFAULT false, attempts integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
ALTER TABLE public.app_inventory_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_inventory_deletions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_inventory_deletions TO service_role;
CREATE FUNCTION public.findez_delete_inventory_contents(p_actor uuid,p_inventory uuid,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; ref record; linked boolean; files jsonb; receipt record;
BEGIN
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 IF inv.team_id IS NOT NULL THEN
  PERFORM 1 FROM public.team_memberships WHERE team_id=inv.team_id AND user_id=p_actor FOR SHARE;
 END IF;
 PERFORM 1 FROM public.app_inventory_members WHERE inventory_id=p_inventory AND user_id=p_actor FOR SHARE;
 IF NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin'),false) THEN RAISE insufficient_privilege; END IF;
 IF p_name IS DISTINCT FROM inv.name THEN RAISE invalid_parameter_value; END IF;
 -- Fail closed when a future table's deletion semantics have not been reviewed.
 FOR ref IN SELECT c.conrelid::regclass::text AS table_name,c.confdeltype FROM pg_constraint c
  WHERE c.contype='f' AND c.confrelid='public.app_inventories'::regclass
 LOOP
  IF ref.table_name NOT IN ('items','spaces','bins','documents','capture_reviews','conversations','messages',
    'checkouts','item_events','project_kits','project_kit_items','project_kit_reservations','conversation_history',
    'query_logs','inventory_user_memory','inventory_conversation_sessions','activity_log','team_shares',
    'app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events')
    OR ref.confdeltype NOT IN ('c','n') THEN RAISE check_violation USING message='Unreviewed inventory dependency'; END IF;
 END LOOP;
 -- Never cascade or detach a record belonging to a different inventory.
 FOR ref IN
  SELECT child_ns.nspname AS child_schema,child.relname AS child_table,ca.attname AS child_column,
   parent_ns.nspname AS parent_schema,parent.relname AS parent_table,pa.attname AS parent_column
  FROM pg_constraint c JOIN pg_class child ON child.oid=c.conrelid JOIN pg_namespace child_ns ON child_ns.oid=child.relnamespace
   JOIN pg_class parent ON parent.oid=c.confrelid JOIN pg_namespace parent_ns ON parent_ns.oid=parent.relnamespace
   JOIN pg_attribute ca ON ca.attrelid=c.conrelid AND ca.attnum=c.conkey[1]
   JOIN pg_attribute pa ON pa.attrelid=c.confrelid AND pa.attnum=c.confkey[1]
  WHERE c.contype='f' AND cardinality(c.conkey)=1
   AND EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid=parent.oid AND a.attname='inventory_id' AND NOT a.attisdropped)
   AND EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid=child.oid AND a.attname='inventory_id' AND NOT a.attisdropped)
 LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I c JOIN %I.%I p ON c.%I=p.%I WHERE p.inventory_id=$1 AND c.inventory_id IS DISTINCT FROM $1)',
   ref.child_schema,ref.child_table,ref.parent_schema,ref.parent_table,ref.child_column,ref.parent_column)
   INTO linked USING p_inventory;
  IF linked THEN RAISE check_violation USING message='Records are linked to another inventory'; END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(DISTINCT file),'[]') INTO files FROM (
  SELECT jsonb_build_object('kind','document','path',storage_path,'owner',user_id) AS file
   FROM public.documents WHERE inventory_id=p_inventory AND storage_path IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) FROM public.items WHERE inventory_id=p_inventory AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) FROM public.item_events WHERE inventory_id=p_inventory AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) FROM public.capture_reviews WHERE inventory_id=p_inventory AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',source_frame_url,'owner',user_id) FROM public.capture_reviews WHERE inventory_id=p_inventory AND source_frame_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',v #>> '{}','owner',r.user_id)
   FROM public.capture_reviews r CROSS JOIN LATERAL jsonb_path_query(r.scan_evidence,'$.** ? (@.type() == "string")') v
   WHERE r.inventory_id=p_inventory AND (v #>> '{}') LIKE '%/storage/v1/object/%'
 ) objects;
 INSERT INTO public.app_inventory_deletions(inventory_id,actor_id,files) VALUES(p_inventory,p_actor,files);
 INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,inv.team_id,p_inventory,'inventory_delete',p_inventory,jsonb_build_object('delete_contents',true));
 DELETE FROM public.app_inventories WHERE inventory_id=p_inventory;
 IF inv.is_default THEN
  UPDATE public.app_inventories SET is_default=true WHERE inventory_id=(SELECT inventory_id FROM public.app_inventories
   WHERE owner_user_id=inv.owner_user_id AND team_id IS NOT DISTINCT FROM inv.team_id ORDER BY created_at,inventory_id LIMIT 1 FOR UPDATE);
 END IF;
 RETURN jsonb_build_object('deleted',true,'inventory_id',p_inventory,'delete_contents',true);
END $$;
REVOKE ALL ON FUNCTION public.findez_delete_inventory_contents(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_delete_inventory_contents(uuid,uuid,text) TO service_role;

-- Account removal prepares a manifest before Auth deletes identity. Cleanup may
-- only run after identity is absent, so an Auth/FK failure cannot erase content.
CREATE TABLE public.app_account_deletions (
 actor_id uuid PRIMARY KEY, files jsonb NOT NULL, completed boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
ALTER TABLE public.app_account_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_account_deletions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_account_deletions TO service_role;
-- Preserve another inventory's loan history when a borrower removes identity.
DO $$ DECLARE c record; BEGIN
 IF to_regclass('public.checkouts') IS NOT NULL THEN
  ALTER TABLE public.checkouts ALTER COLUMN user_id DROP NOT NULL;
  FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.checkouts'::regclass AND confrelid='auth.users'::regclass
   AND conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='public.checkouts'::regclass AND attname='user_id')]::smallint[]
  LOOP EXECUTE format('ALTER TABLE public.checkouts DROP CONSTRAINT %I',c.conname); END LOOP;
  ALTER TABLE public.checkouts ADD CONSTRAINT checkouts_deleted_borrower FOREIGN KEY(user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
 END IF;
END $$;
CREATE FUNCTION public.findez_prepare_account_deletion(p_actor uuid,p_files jsonb DEFAULT '[]')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE files jsonb;
BEGIN
 PERFORM 1 FROM auth.users WHERE id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
 IF EXISTS(SELECT 1 FROM public.app_organizations WHERE owner_user_id=p_actor) THEN
  RETURN jsonb_build_object('ready',false,'code','OWNERSHIP_REQUIRED','error','Delete or transfer the organizations you own before deleting your account. Open Organizations to manage them.');
 END IF;
 IF EXISTS(SELECT 1 FROM public.teams WHERE owner_user_id=p_actor) THEN
  RETURN jsonb_build_object('ready',false,'code','OWNERSHIP_REQUIRED','error','Delete or transfer the workspaces you own before deleting your account. Open Workspace settings to manage them.');
 END IF;
 IF EXISTS(SELECT 1 FROM public.spaces r JOIN public.app_inventories i USING(inventory_id) WHERE r.user_id=p_actor AND i.owner_user_id<>p_actor)
 OR EXISTS(SELECT 1 FROM public.items r JOIN public.app_inventories i USING(inventory_id) WHERE r.user_id=p_actor AND i.owner_user_id<>p_actor)
 OR EXISTS(SELECT 1 FROM public.documents r JOIN public.app_inventories i USING(inventory_id) WHERE r.user_id=p_actor AND i.owner_user_id<>p_actor) THEN
  RETURN jsonb_build_object('ready',false,'code','SHARED_RECORDS','error','Some records you created belong to another account. Ask its owner to transfer those records before deleting your account.');
 END IF;
 IF jsonb_typeof(p_files)<>'array' THEN RAISE invalid_parameter_value; END IF;
 SELECT coalesce(jsonb_agg(DISTINCT file),'[]') INTO files FROM (
  SELECT jsonb_build_object('kind','document','path',storage_path,'owner',p_actor) AS file FROM public.documents WHERE user_id=p_actor AND storage_path IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.items WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.item_events WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.capture_reviews WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',source_frame_url,'owner',p_actor) FROM public.capture_reviews WHERE user_id=p_actor AND source_frame_url IS NOT NULL
  UNION ALL SELECT value FROM jsonb_array_elements(p_files)
 ) objects;
 INSERT INTO public.app_account_deletions(actor_id,files) VALUES(p_actor,files)
 ON CONFLICT(actor_id) DO UPDATE SET files=(SELECT coalesce(jsonb_agg(DISTINCT value),'[]') FROM jsonb_array_elements(app_account_deletions.files||EXCLUDED.files));
 RETURN jsonb_build_object('ready',true);
END $$;
CREATE FUNCTION public.findez_finish_account_deletion(p_actor uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE t text; col text;
BEGIN
 PERFORM 1 FROM public.app_account_deletions WHERE actor_id=p_actor FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RETURN false; END IF;
 -- Auth already cascaded canonical inventories and private history. Remove
 -- remaining legacy rows in one transaction, never a sequence of HTTP deletes.
 FOREACH t IN ARRAY ARRAY['team_notification_reads','push_devices','email_deliveries','team_notification_recipients',
   'team_members','team_memberships','item_events','documents','activity_log','usage_counters','query_logs',
   'conversation_history','inventory_conversation_sessions','conversation_sessions','conversations',
   'inventory_user_memory','user_memory','user_plan','usage_limits','bins','items','spaces','team_shares','profiles']
 LOOP
  col:=CASE WHEN t='team_members' THEN 'member_user_id' WHEN t='team_shares' THEN 'owner_user_id' WHEN t='profiles' THEN 'id' ELSE 'user_id' END;
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=t AND column_name=col) THEN
   EXECUTE format('DELETE FROM public.%I WHERE %I=$1',t,col) USING p_actor;
  END IF;
 END LOOP;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.findez_prepare_account_deletion(uuid,jsonb),public.findez_finish_account_deletion(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_prepare_account_deletion(uuid,jsonb),public.findez_finish_account_deletion(uuid) TO service_role;

-- A deleted identity's still-unexpired JWT must not read/write private objects.
CREATE FUNCTION public.findez_active_storage_account() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid());
$$;
REVOKE ALL ON FUNCTION public.findez_active_storage_account() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_active_storage_account() TO authenticated;
DO $$ BEGIN
 IF to_regclass('storage.objects') IS NOT NULL THEN
  CREATE POLICY findez_active_storage_account ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
   USING(public.findez_active_storage_account()) WITH CHECK(public.findez_active_storage_account());
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
