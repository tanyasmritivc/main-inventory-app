"""Offline quality reporting. Satisfaction is not a correctness training label."""
from collections import Counter, defaultdict
from app.services.response_feedback import DIMENSIONS

DIMENSION_NAMES = frozenset(DIMENSIONS.values()) - {'unclassified'}


def summarize(rows, eligible_responses, *, minimum_group=5):
    counts = Counter(row.get('rating') for row in rows)
    reasons = Counter(row.get('reason') for row in rows if row.get('rating') == -1)
    groups = defaultdict(list)
    reviewed = []
    operations = defaultdict(list)
    for row in rows:
        d = row.get('diagnostics') or {}
        for operation in d.get('operations', []):
            operations[str(operation.get('operation', 'unknown'))[:80]].append((operation.get('result'), row.get('rating')))
        for key in ('operation', 'model_version', 'response_version', 'execution'):
            groups[(key, str(d.get(key, 'unknown'))[:100])].append(row)
        if row.get('review_status') in ('reviewed', 'resolved'):
            labels = {k: v for k, v in (row.get('reviewed_labels') or {}).items()
                      if k in DIMENSION_NAMES and v in ('correct', 'incorrect')}
            if labels:
                reviewed.append({'labels': labels, 'operation': d.get('operation', 'unknown'),
                    'model_version': d.get('model_version', 'unknown'),
                    'response_version': d.get('response_version', 'unknown')})
    rated = counts[1] + counts[-1]
    return {'eligible_responses': eligible_responses, 'rated_responses': rated,
        'coverage': rated / eligible_responses if eligible_responses else None,
        'positive_rate': counts[1] / rated if rated else None,
        'negative_rate': counts[-1] / rated if rated else None,
        'negative_reasons': {k: v for k, v in reasons.items() if k in DIMENSIONS},
        'groups': [{'dimension': key, 'value': value, 'rated': len(group),
            'negative_rate': sum(r.get('rating') == -1 for r in group) / len(group)}
            for (key, value), group in sorted(groups.items()) if len(group) >= minimum_group],
        'operation_outcomes': [{'operation': name, 'observations': len(values),
            'database_confirmed': sum(result == 'database_confirmed' for result, _ in values),
            'rejected': sum(result == 'rejected' for result, _ in values),
            'negative_ratings': sum(rating == -1 for _, rating in values)}
            for name, values in sorted(operations.items()) if len(values) >= minimum_group],
        'reviewed_examples': reviewed,
        'caveat': 'Voluntary ratings are selection-biased satisfaction signals. Unrated and unreviewed responses are not correctness labels.'}


def compare_fixed_cases(baseline, candidate):
    """Operator supplies fixed synthetic/adjudicated case IDs and measured outcomes."""
    if set(baseline) != set(candidate): raise ValueError('Compare the same fixed evaluation cases')
    regressions = []
    for case_id in baseline:
        for dimension in DIMENSION_NAMES:
            before, after = baseline[case_id].get(dimension), candidate[case_id].get(dimension)
            if before == 'correct' and after == 'incorrect':
                regressions.append({'case': case_id, 'dimension': dimension})
    return {'cases': len(baseline), 'regressions': regressions, 'passed': not regressions}
