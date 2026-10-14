-- Derive migration progress from existing catalog and confirmed physical memory.
BEGIN;
CREATE FUNCTION public.shopify_adoption_report(p_team uuid,p_connection uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; member_role text; result jsonb; BEGIN
 SELECT role INTO member_role FROM team_memberships WHERE team_id=p_team AND user_id=p_actor;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','permission'); END IF;
 SELECT * INTO c FROM shopify_connections WHERE team_id=p_team AND connection_id=p_connection;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','permission'); END IF;
 IF c.status NOT IN ('connected','reconnect_required') THEN RETURN jsonb_build_object('error','reconnect'); END IF;
 WITH progress AS (
  SELECT v.variant_gid,v.product_title,v.variant_title,v.sku,
   coalesce(bool_or(p.placement_id IS NOT NULL),false) AS mapped,
   coalesce(bool_or(p.confirmed_at<=now()-interval '7 days'),false) AS has_old_confirmation
  FROM shopify_variants v
  LEFT JOIN physical_commerce_links l ON l.connection_id=v.connection_id AND l.variant_gid=v.variant_gid
  LEFT JOIN physical_memories m ON m.memory_id=l.memory_id AND m.team_id=p_team
  LEFT JOIN physical_placements p ON p.memory_id=m.memory_id AND p.status='active'
   AND EXISTS(SELECT 1 FROM team_spaces ts JOIN spaces s ON s.id=ts.space_id
     WHERE ts.team_id=p_team AND s.id=p.space_id AND (NOT p.had_bin OR EXISTS(
       SELECT 1 FROM bins b WHERE b.id=p.bin_id AND b.space_id=s.id AND b.user_id=s.user_id)))
  WHERE v.connection_id=p_connection AND v.deleted_at IS NULL
  GROUP BY v.variant_gid,v.product_title,v.variant_title,v.sku
 ) SELECT jsonb_build_object(
  'total_variants',count(*),
  'confirmed_variants',count(*) FILTER(WHERE mapped),
  'unconfirmed_variants',count(*) FILTER(WHERE NOT mapped),
  'older_confirmations',count(*) FILTER(WHERE has_old_confirmation),
  'unconfirmed_sample',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
    SELECT variant_gid,product_title,variant_title,sku FROM progress WHERE NOT mapped
    ORDER BY product_title,variant_title,variant_gid LIMIT 5) x),'[]'),
  'confirmed_example',(SELECT to_jsonb(x) FROM (
    SELECT variant_gid,product_title,variant_title,sku FROM progress WHERE mapped
    ORDER BY product_title,variant_title,variant_gid LIMIT 1) x)
 ) INTO result FROM progress;
 RETURN result||jsonb_build_object('connection_id',p_connection,'connection_status',c.status,'checked_at',now(),
  'sync_in_progress',c.sync_requested OR EXISTS(SELECT 1 FROM shopify_sync_jobs WHERE connection_id=p_connection),
  'can_confirm',member_role IN ('owner','mentor','member') AND c.status='connected',
  'space_count',(SELECT count(*) FROM team_spaces ts JOIN spaces s ON s.id=ts.space_id WHERE ts.team_id=p_team),
  'import_complete',coalesce(c.installed_at IS NOT NULL AND c.last_success_at>=c.installed_at,false),
  'last_complete_sync',c.last_success_at);
END $$;
REVOKE ALL ON FUNCTION public.shopify_adoption_report(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.shopify_adoption_report(uuid,uuid,uuid) TO service_role;
COMMIT;
