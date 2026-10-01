-- Preserve the authorized evidence snapshot shown with an Ask response.
-- Existing conversation ownership RLS continues to protect this column.
begin;
alter table public.messages
    add column if not exists answer_context jsonb;

alter table public.messages
    add constraint messages_answer_context_object
    check (answer_context is null or (
        role = 'assistant' and jsonb_typeof(answer_context) = 'object'
    ));

comment on column public.messages.answer_context is
    'Public source/result snapshot at answer time; no raw tool arguments or internal reasoning.';
notify pgrst, 'reload schema';
commit;
