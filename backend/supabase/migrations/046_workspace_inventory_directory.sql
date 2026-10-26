-- Discoverability is separate from content access. Existing grants stay unchanged.
BEGIN;
ALTER TABLE public.app_inventories ADD COLUMN directory_visibility text NOT NULL DEFAULT 'workspace'
 CHECK(directory_visibility IN ('workspace','hidden'));
ALTER TABLE public.app_inventories ADD COLUMN directory_description text NOT NULL DEFAULT ''
 CHECK(length(directory_description)<=500);
CREATE TABLE public.app_inventory_access_requests (
 request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 inventory_id uuid NOT NULL REFERENCES public.app_inventories ON DELETE CASCADE,
 team_id uuid NOT NULL REFERENCES public.teams ON DELETE CASCADE,
 requester_user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','declined','cancelled','expired')),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '7 days',
 decided_at timestamptz, decided_by uuid REFERENCES auth.users ON DELETE SET NULL
);
CREATE UNIQUE INDEX inventory_request_pending ON public.app_inventory_access_requests(inventory_id,requester_user_id) WHERE status='pending';
ALTER TABLE public.app_inventory_access_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_inventory_access_requests FROM public,anon,authenticated;
GRANT ALL ON public.app_inventory_access_requests TO service_role;

CREATE FUNCTION public.findez_directory_entry(p_inventory uuid,p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object('inventory_id',i.inventory_id,'workspace_id',coalesce(i.team_id::text,'personal'),
 'name',i.name,'description',i.directory_description,'can_open',r.role IS NOT NULL,
 'can_edit',coalesce(r.role IN ('owner','admin','editor'),false),
 'can_manage',coalesce(r.role IN ('owner','admin'),false),
 'can_rename',coalesce(r.role IS NOT NULL AND (i.created_by_user_id=p_actor OR r.role IN ('owner','admin')),false),
 'directory_visibility',i.directory_visibility,'role',r.role)
 || CASE WHEN r.role IS NOT NULL THEN jsonb_build_object('item_count',(SELECT count(*) FROM public.items x WHERE x.inventory_id=i.inventory_id)) ELSE '{}'::jsonb END
 FROM public.app_inventories i
 CROSS JOIN LATERAL (SELECT public.findez_inventory_role(i.inventory_id,p_actor) AS role) r
 WHERE i.inventory_id=p_inventory AND (r.role IS NOT NULL OR (i.directory_visibility='workspace'
 AND EXISTS(SELECT 1 FROM public.team_memberships m WHERE m.team_id=i.team_id AND m.user_id=p_actor)))
$$;
REVOKE ALL ON FUNCTION public.findez_directory_entry(uuid,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_directory_entry(uuid,uuid) TO service_role;

CREATE FUNCTION public.findez_workspace_directory(p_actor uuid,p_action text,p_data jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE ws uuid:=nullif(p_data->>'workspace_id','personal')::uuid;
 inv uuid:=(p_data->>'inventory_id')::uuid; req uuid:=(p_data->>'request_id')::uuid;
 entry jsonb; saved jsonb; old_value jsonb; request_row public.app_inventory_access_requests;
 created_count integer; records jsonb; total bigint; start_at integer:=coalesce((p_data->>'offset')::integer,0);
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 IF p_action='list' THEN
  IF ws IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor) THEN RAISE insufficient_privilege; END IF;
  IF start_at<0 THEN RAISE check_violation; END IF;
  WITH visible AS MATERIALIZED (
   SELECT i.inventory_id,i.name,i.directory_description FROM public.app_inventories i
   WHERE (ws IS NOT NULL AND i.team_id=ws OR ws IS NULL AND i.team_id IS NULL AND i.owner_user_id=p_actor)
    AND (public.findez_inventory_role(i.inventory_id,p_actor) IS NOT NULL OR (i.directory_visibility='workspace' AND ws IS NOT NULL))
    AND (coalesce(p_data->>'query','')='' OR strpos(lower(i.name),lower(p_data->>'query'))>0 OR strpos(lower(i.directory_description),lower(p_data->>'query'))>0)
  ) SELECT (SELECT count(*) FROM visible),coalesce((SELECT jsonb_agg(public.findez_directory_entry(inventory_id,p_actor) ORDER BY lower(name),inventory_id) FROM
   (SELECT inventory_id,name FROM visible ORDER BY lower(name),inventory_id LIMIT 100 OFFSET start_at) page),'[]'::jsonb)
  INTO total,records;
  RETURN jsonb_build_object('inventories',records,'total',total,'next_offset',CASE WHEN start_at+jsonb_array_length(records)<total THEN start_at+jsonb_array_length(records) END);
 END IF;
 IF p_action IN ('approve','decline','cancel') THEN
  SELECT * INTO request_row FROM public.app_inventory_access_requests WHERE request_id=req;
  IF NOT FOUND THEN RAISE no_data_found; END IF;
  inv:=request_row.inventory_id;
 END IF;
 IF p_action='requests' THEN
  IF NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor) THEN RAISE insufficient_privilege; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('request_id',r.request_id,'inventory_id',r.inventory_id,
   'inventory_name',i.name,'requester_name',coalesce(nullif(p.display_name,''),'Workspace member'),
   'created_at',r.created_at,'expires_at',r.expires_at,'status',r.status) ORDER BY r.created_at),'[]'::jsonb) INTO records
  FROM public.app_inventory_access_requests r JOIN public.app_inventories i USING(inventory_id)
  LEFT JOIN public.profiles p ON p.id=r.requester_user_id
  WHERE r.team_id=ws AND i.team_id=ws AND r.status='pending' AND r.expires_at>now()
   AND EXISTS(SELECT 1 FROM public.team_memberships m WHERE m.team_id=ws AND m.user_id=r.requester_user_id)
   AND public.findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin');
  RETURN records;
 END IF;
 SELECT team_id INTO ws FROM public.app_inventories WHERE inventory_id=inv;
 IF p_action<>'entry' THEN
  IF ws IS NOT NULL THEN PERFORM 1 FROM public.teams WHERE team_id=ws FOR UPDATE; END IF;
  PERFORM 1 FROM public.app_inventories WHERE inventory_id=inv FOR UPDATE;
 END IF;
 entry:=public.findez_directory_entry(inv,p_actor);
 IF entry IS NULL THEN RAISE no_data_found; END IF;
 IF p_data ? 'workspace_id' AND coalesce(ws::text,'personal')<>p_data->>'workspace_id' THEN RAISE no_data_found; END IF;
 IF p_action='entry' THEN
  SELECT jsonb_build_object('request_id',request_id,'status',status,'expires_at',expires_at) INTO saved
   FROM public.app_inventory_access_requests WHERE inventory_id=inv AND requester_user_id=p_actor AND team_id=ws
   AND status='pending' AND expires_at>now();
  RETURN jsonb_build_object('inventory',entry,'request',saved);
 ELSIF p_action='settings' THEN
  IF NOT coalesce((entry->>'can_manage')::boolean,false) THEN RAISE insufficient_privilege; END IF;
  IF p_data->>'directory_visibility' IS NULL OR p_data->>'description' IS NULL OR p_data->>'directory_visibility' NOT IN ('workspace','hidden') OR length(p_data->>'description')>500 THEN RAISE check_violation; END IF;
  SELECT jsonb_build_object('directory_visibility',directory_visibility,'description',directory_description) INTO old_value FROM public.app_inventories WHERE inventory_id=inv;
  UPDATE public.app_inventories SET directory_visibility=p_data->>'directory_visibility',directory_description=btrim(p_data->>'description') WHERE inventory_id=inv;
  saved:=public.findez_directory_entry(inv,p_actor);
 ELSIF p_action='request' THEN
  IF ws IS NULL OR (entry->>'can_open')::boolean THEN RAISE check_violation; END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor AND email_confirmed_at IS NOT NULL) THEN RAISE insufficient_privilege; END IF;
  UPDATE public.app_inventory_access_requests SET status='expired',decided_at=now() WHERE inventory_id=inv AND requester_user_id=p_actor AND status='pending' AND expires_at<=now();
  INSERT INTO public.app_inventory_access_requests(inventory_id,team_id,requester_user_id) VALUES(inv,ws,p_actor)
   ON CONFLICT(inventory_id,requester_user_id) WHERE status='pending' DO NOTHING;
  GET DIAGNOSTICS created_count=ROW_COUNT;
  SELECT jsonb_build_object('request_id',request_id,'status',status,'expires_at',expires_at) INTO saved
   FROM public.app_inventory_access_requests WHERE inventory_id=inv AND requester_user_id=p_actor AND status='pending';
  IF created_count=1 THEN
   INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
   VALUES(p_actor,ws,inv,'directory_request',(saved->>'request_id')::uuid,jsonb_build_object('requested_role','viewer'));
  END IF;
  RETURN saved; -- No grant; the requester explicitly consents to viewer access only.
 ELSIF p_action IN ('approve','decline','cancel') THEN
  SELECT * INTO request_row FROM public.app_inventory_access_requests WHERE request_id=req FOR UPDATE;
  IF p_action='cancel' THEN
   IF request_row.requester_user_id<>p_actor THEN RAISE insufficient_privilege; END IF;
  ELSIF NOT coalesce((entry->>'can_manage')::boolean,false) THEN RAISE insufficient_privilege;
  END IF;
  IF request_row.team_id<>ws OR NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=request_row.requester_user_id) THEN RAISE check_violation; END IF;
  IF request_row.status<>'pending' THEN RETURN jsonb_build_object('request_id',req,'status',request_row.status); END IF;
  IF request_row.expires_at<=now() THEN RAISE check_violation; END IF;
  IF p_action='approve' AND public.findez_inventory_role(inv,request_row.requester_user_id) IS NULL THEN
   INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,request_row.requester_user_id,'viewer')
    ON CONFLICT(inventory_id,user_id) DO UPDATE SET role='viewer';
  END IF;
  UPDATE public.app_inventory_access_requests SET status=CASE p_action WHEN 'approve' THEN 'approved' WHEN 'decline' THEN 'declined' ELSE 'cancelled' END,
   decided_at=now(),decided_by=p_actor WHERE request_id=req
   RETURNING jsonb_build_object('request_id',request_id,'status',status) INTO saved;
 ELSE RAISE check_violation;
 END IF;
 INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,ws,inv,'directory_'||p_action,req,jsonb_build_object('before',old_value,'after',saved));
 RETURN saved;
END $$;
REVOKE ALL ON FUNCTION public.findez_workspace_directory(uuid,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_workspace_directory(uuid,text,jsonb) TO service_role;
COMMIT;
