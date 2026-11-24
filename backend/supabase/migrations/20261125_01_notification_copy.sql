BEGIN;
-- Keep the existing daily decision and account-safe fallback destination.
CREATE OR REPLACE FUNCTION public.findez_alert_template(category text) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE category
 WHEN 'first_item' THEN jsonb_build_object('title','What do you look for most?','body','Add one item and save where you keep it.')
 WHEN 'add_item' THEN jsonb_build_object('title','Have you picked up anything new recently?','body','Record a purchase or part so you can find it later.')
 WHEN 'snap' THEN jsonb_build_object('title','One shelf, one quick photo','body','Open Scan and review what FindEZ picks out.')
 WHEN 'expiry' THEN jsonb_build_object('title','Check an upcoming expiry','body','Open the item to check its recorded expiry date.')
 WHEN 'locate_item' THEN jsonb_build_object('title','Give one item a home','body','Save its missing location so you can find it again.')
 WHEN 'scan_review' THEN jsonb_build_object('title','Your photo is ready to review','body','Check the extracted items before saving them.')
 END
$$;
ALTER FUNCTION public.findez_notification_content(uuid) RENAME TO findez_inventory_alert_content;
CREATE FUNCTION public.findez_notification_content(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE WHEN c IS NULL THEN NULL
   WHEN n.category='daily_inventory' AND c->>'title'='Your inventory check-in' THEN
     c||jsonb_build_object('title','What would you like to find faster?','body','Open FindEZ and choose what you want to keep track of today.')
   ELSE c||coalesce(findez_alert_template(n.category),'{}'::jsonb) END
 FROM personalization_notifications n CROSS JOIN LATERAL (SELECT findez_inventory_alert_content(n.id) AS c) content WHERE n.id=p_id
$$;
REVOKE ALL ON FUNCTION findez_notification_content(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_notification_content(uuid) TO service_role;
COMMIT;
