# Onboarding answers

The optional iOS setup asks about intended use, inventory types, primary goal and
working alone or with others. Users can update their answers from Profile using
Setup questions. Answers guide the starter advice and product improvements; they
do not automatically create or share inventory, Spaces or Teams.

Migration 041 creates `public.onboarding_responses`, one latest row per auth user.
`GET /profile/onboarding` and `PUT /profile/onboarding` are authenticated and bind
the row to the requester. Direct authenticated access is owner-readable only;
integration keys cannot read it. Writes go through the backend and account
deletion cascades to answers. Optional custom labels are bounded to 80 characters.
No email or inventory content is copied into the answer row.

| Question | Stored columns |
| --- | --- |
| Intended use | `use_case`, optional `use_case_other` |
| What they manage | `inventory_types`, optional `inventory_other` |
| Main goal | `primary_goal` |
| Alone or with others | `collaboration` (`solo` or `others`) |

The operator can review aggregate answers through authorized database access:

```sql
SELECT use_case, primary_goal, collaboration, count(*) AS accounts
FROM public.onboarding_responses
GROUP BY use_case, primary_goal, collaboration
ORDER BY accounts DESC;
```

Inventory types allow multiple selections. Count accounts choosing each type:

```sql
SELECT selected.inventory_type, count(*) AS accounts
FROM public.onboarding_responses
CROSS JOIN LATERAL unnest(inventory_types) AS selected(inventory_type)
GROUP BY selected.inventory_type
ORDER BY accounts DESC;
```

Use privileged access only when inspecting individual answers. Team membership
never grants access to another person's setup answers. Pre-sign-in responses
stay on the device until a successful sign-in; failed uploads remain bound to
that account for retry. No third-party analytics or advertising tracker is added.
