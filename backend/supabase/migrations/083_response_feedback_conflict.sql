-- Expected revision conflicts are HTTP 409, not retryable database failures.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_response_feedback(p_actor uuid,p_message uuid,p_rating integer,
 p_reason text,p_comment text,p_revision bigint,p_diagnostics jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE cid uuid; world text; prior public.response_feedback; output public.response_feedback; generation bigint;
BEGIN
 IF NOT coalesce(public.findez_actor_active(p_actor),false) THEN RAISE insufficient_privilege; END IF;
 SELECT c.id,c.world_key INTO STRICT cid,world FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 WHERE m.id=p_message AND c.user_id=p_actor AND m.role='assistant' AND length(btrim(m.content))>0
 AND NOT coalesce((m.answer_context->>'direct_receipt')::boolean,false)
 AND NOT coalesce((m.answer_context->>'attachment_receipt')::boolean,false)
 AND NOT coalesce((m.answer_context->>'response_failed')::boolean,false) FOR SHARE OF m,c;
 IF world IS NOT NULL AND world<>'personal' AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id::text=world AND user_id=p_actor) THEN RAISE insufficient_privilege; END IF;
 IF p_rating IS NULL OR p_rating NOT IN (-1,1) OR p_revision IS NULL OR p_revision<0
 OR (p_rating=1 AND p_reason IS NOT NULL) OR length(p_comment)>1000
 OR jsonb_typeof(p_diagnostics) IS DISTINCT FROM 'object' OR octet_length(p_diagnostics::text)>4096 THEN RAISE check_violation; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text||':'||p_message::text,82));
 SELECT * INTO prior FROM public.response_feedback WHERE user_id=p_actor AND message_id=p_message FOR UPDATE;
 IF FOUND THEN
  IF prior.rating=p_rating AND prior.reason IS NOT DISTINCT FROM p_reason AND prior.comment IS NOT DISTINCT FROM p_comment THEN RETURN to_jsonb(prior); END IF;
  IF prior.revision<>p_revision THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Feedback changed. Refresh and try again.'; END IF;
 ELSIF p_revision<>0 THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Feedback changed. Refresh and try again.';
 END IF;
 IF public.findez_personalization_enabled(p_actor) THEN
  SELECT p.generation INTO generation FROM public.personalization_profiles p WHERE p.user_id=p_actor;
 END IF;
 INSERT INTO public.response_feedback(user_id,message_id,conversation_id,rating,reason,comment,learning_generation,diagnostics)
 VALUES(p_actor,p_message,cid,p_rating,p_reason,nullif(btrim(p_comment),''),generation,p_diagnostics)
 ON CONFLICT(user_id,message_id) DO UPDATE SET rating=excluded.rating,reason=excluded.reason,comment=excluded.comment,
 diagnostics=excluded.diagnostics,learning_generation=excluded.learning_generation,
 revision=response_feedback.revision+1,updated_at=now(),review_status='unreviewed',reviewed_labels='{}'
 RETURNING * INTO output;
 RETURN to_jsonb(output);
END $$;
REVOKE ALL ON FUNCTION public.findez_response_feedback(uuid,uuid,integer,text,text,bigint,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_response_feedback(uuid,uuid,integer,text,text,bigint,jsonb) TO service_role;

COMMIT;
