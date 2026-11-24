BEGIN;
CREATE FUNCTION findez_assign_alert_variant() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF NEW.attempted_at IS NULL AND NEW.category IN ('first_item','add_item') THEN
  NEW.experiment_variant:=CASE WHEN (SELECT add_experiment FROM notification_channel_policy WHERE singleton)
   THEN CASE WHEN get_byte(decode(md5('add-copy-v1/'||NEW.user_id::text),'hex'),0)%2=0 THEN 'add-v1/A' ELSE 'add-v1/B' END END;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER choose_notification_variant BEFORE INSERT OR UPDATE OF state ON personalization_notifications
 FOR EACH ROW WHEN (NEW.state IN ('pending','sending')) EXECUTE FUNCTION findez_assign_alert_variant();
ALTER FUNCTION findez_notification_content(uuid) RENAME TO findez_opportunity_content;
CREATE FUNCTION findez_notification_content(p_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; content jsonb; last_seen timestamptz;
BEGIN
 content:=findez_opportunity_content(p_id);
 IF content IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF n.category IN ('first_item','add_item') THEN
  SELECT last_foreground_at INTO last_seen FROM notification_preferences WHERE user_id=n.user_id;
  IF n.experiment_variant='add-v1/A' THEN
    RETURN content||jsonb_build_object('title','Give FindEZ one more item to remember','body','Add something you want to find again.');
  ELSIF n.experiment_variant='add-v1/B' THEN
    RETURN content||jsonb_build_object('title','Have you picked up anything new recently?','body','Add something you want to find again.');
  ELSIF last_seen<now()-interval '4 days' THEN
    RETURN content||jsonb_build_object('title','Have a minute for your inventory?','body','Record something new while its details are fresh.');
  END IF;
 END IF;
 RETURN content;
END $$;
-- Activity suppresses optional prompts at claim and immediately before sending.
ALTER FUNCTION findez_notification_eligible(uuid,timestamptz) RENAME TO findez_inventory_notification_eligible;
CREATE FUNCTION findez_notification_eligible(p_id uuid,p_at timestamptz) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(findez_inventory_notification_eligible(p_id,p_at),(
   SELECT 'active_session' FROM personalization_notifications n JOIN notification_preferences p USING(user_id)
   WHERE n.id=p_id AND n.category IN ('first_item','add_item','snap') AND p.last_foreground_at>p_at-interval '1 hour'))
$$;
CREATE FUNCTION findez_notification_public_policy() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object('daily_inventory_hour',morning_hour,'evening_inventory_hour',evening_hour,'daily',event_daily,'weekly',event_weekly,
 'noncritical_hours',extract(epoch FROM event_gap)/3600,'local_alerts',false,'engagement_daily',engagement_daily,
 'suggestions_daily',suggestions_daily,'discoveries_weekly',discoveries_weekly,'insights_weekly',insights_weekly,
 'spacing_minutes',extract(epoch FROM spacing)/60) FROM notification_channel_policy
$$;
CREATE FUNCTION findez_notification_analytics() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH cohort AS MATERIALIZED (
 SELECT n.*,findez_notification_action(n) AS intended_action FROM personalization_notifications n
 WHERE n.policy_version=1 AND n.created_at>=now()-interval '30 days'
 ), counts AS (
 SELECT n.*,
  coalesce(a.attempts,0) AS provider_calls,coalesce(a.accepts,0) AS accepts,coalesce(a.rejects,0) AS rejects,coalesce(a.unknowns,0) AS unknowns,
  coalesce(r.after_visit,0) AS after_visit,coalesce(r.added,0) AS added,coalesce(r.units,0) AS units,coalesce(o.disabled,0) AS disables
 FROM cohort n
 LEFT JOIN (SELECT notification_id,count(*) AS attempts,count(*) FILTER(WHERE outcome='accepted') AS accepts,
 count(*) FILTER(WHERE outcome='rejected') AS rejects,count(*) FILTER(WHERE outcome='unknown') AS unknowns
 FROM notification_provider_receipts GROUP BY notification_id) a ON a.notification_id=n.id
 LEFT JOIN (SELECT notification_id,count(*) FILTER(WHERE action='item_added') AS added,count(*) FILTER(WHERE action='addition_after_visit') AS after_visit,count(*) FILTER(WHERE action NOT IN ('addition_after_visit','capture_queued')) AS units
 FROM notification_action_results GROUP BY notification_id) r ON r.notification_id=n.id
 LEFT JOIN (SELECT notification_id,count(*) AS disabled FROM notification_disablements GROUP BY notification_id) o ON o.notification_id=n.id
 ), grouped AS (
 SELECT CASE WHEN grouping(category)=0 THEN category ELSE 'All categories' END AS category,
 CASE WHEN grouping(experiment_variant)=0 THEN experiment_variant END AS variant,
 count(*) AS selected,count(scheduled_for) AS scheduled,sum(provider_calls) AS submitted,sum(rejects) AS rejected,sum(unknowns) AS unknown,
 count(accepted_at) AS accepted,count(accepted_at) FILTER(WHERE interaction_capable) AS measurable_accepted,count(delivered_at) AS app_reported_received,count(push_tapped_at) AS taps,
 count(destination_at) AS destinations,count(action_started_at) AS started,count(workflow_finished_at) AS completed,
 sum(units) AS action_units,sum(added) AS attributed_additions,sum(after_visit) AS additions_after_interaction,sum(disables) AS subsequent_disablements,
 round(100.0*count(push_tapped_at) FILTER(WHERE accepted_at IS NOT NULL AND interaction_capable)/nullif(count(accepted_at) FILTER(WHERE interaction_capable),0),1) AS tap_rate,
 round(100.0*count(workflow_finished_at) FILTER(WHERE accepted_at IS NOT NULL AND interaction_capable AND push_tapped_at IS NOT NULL)/nullif(count(accepted_at) FILTER(WHERE interaction_capable),0),1) AS conversion_rate,
 round(100.0*count(workflow_finished_at) FILTER(WHERE action_started_at IS NOT NULL)/nullif(count(action_started_at),0),1) AS completion_rate
 FROM counts GROUP BY GROUPING SETS((),(category),(category,experiment_variant))
 HAVING grouping(experiment_variant)=1 OR experiment_variant IS NOT NULL
 ), frequency AS (
 SELECT substr(md5('notification-frequency/'||user_id::text),1,16) AS account,count(accepted_at) AS accepted
 FROM cohort GROUP BY user_id
 )
 SELECT jsonb_build_object('days',30,'groups',coalesce((SELECT jsonb_agg(to_jsonb(g) ORDER BY category,variant) FROM grouped g),'[]'),
 'account_frequency',coalesce((SELECT jsonb_agg(to_jsonb(f) ORDER BY accepted DESC,account) FROM frequency f),'[]'),
 'disablements',coalesce((SELECT jsonb_object_agg(setting,total) FROM (SELECT setting,count(*) AS total FROM notification_disablements
 WHERE changed_at>=now()-interval '30 days' GROUP BY setting) d),'{}'),
 'experiment_enabled',(SELECT add_experiment FROM notification_channel_policy))
$$;
REVOKE ALL ON FUNCTION findez_assign_alert_variant(),findez_notification_content(uuid),findez_notification_eligible(uuid,timestamptz),
 findez_notification_public_policy(),findez_notification_analytics() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_notification_content(uuid),findez_notification_eligible(uuid,timestamptz),
 findez_notification_public_policy(),findez_notification_analytics() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
