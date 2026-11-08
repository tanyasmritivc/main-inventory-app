"""Compare frozen, independently reviewed held-out cases. No network or promotion.

python backend/tools/evaluate_recognition.py DATASET.json BASELINE.json CANDIDATE.json
Dataset: {cases: [{id, source_digest, image_digest, expected: {name, ...}}],
          reference_source_digests: [], reference_image_digests: []}
Prediction files: {version: "...", predictions: {case_id: {name, ...}}}
Only explicitly adjudicated fields in expected are scored. Exact normalized label
agreement is a narrow metric, not real-world visual accuracy or a model confidence.
"""
import argparse
import hashlib
import json
import re

FIELDS = frozenset(('name', 'category', 'subcategory', 'brand', 'part_number', 'barcode'))


def normalize(value):
    return ' '.join(str(value or '').casefold().split())


def evaluate(dataset, baseline, candidate, minimum_cases=30):
    cases = dataset.get('cases') or []
    ids = [str(case['id']) for case in cases]
    if not cases or len(set(ids)) != len(ids):
        raise ValueError('Provide nonempty, uniquely identified held-out cases')
    sources = set(dataset.get('reference_source_digests') or [])
    images = set(dataset.get('reference_image_digests') or [])
    for case in cases:
        for key in ('source_digest', 'image_digest'):
            if not re.fullmatch('[a-f0-9]{64}', str(case.get(key) or '')):
                raise ValueError('Every case needs source and crop image digests')
        if case['source_digest'] in sources or case['image_digest'] in images:
            raise ValueError('Held-out evidence overlaps reference data')
        if not isinstance(case.get('expected'), dict) or not case['expected'] or set(case['expected']) - FIELDS:
            raise ValueError('Expected labels must contain adjudicated identity fields only')
    if not baseline.get('version') or not candidate.get('version') or baseline['version'] == candidate['version']:
        raise ValueError('Identify distinct baseline and candidate versions')
    for run in (baseline, candidate):
        if set(run.get('predictions') or {}) != set(ids):
            raise ValueError('Both versions must cover exactly the same held-out cases')
    before = after = total = 0
    regressions, improvements = [], []
    for case in cases:
        case_id = str(case['id'])
        for field, expected in case['expected'].items():
            left = normalize(baseline['predictions'][case_id].get(field)) == normalize(expected)
            right = normalize(candidate['predictions'][case_id].get(field)) == normalize(expected)
            before += left
            after += right
            total += 1
            if left and not right: regressions.append({'case_id': case_id, 'field': field})
            if right and not left: improvements.append({'case_id': case_id, 'field': field})
    enough = len(cases) >= minimum_cases
    return {'dataset_sha256': hashlib.sha256(json.dumps(dataset, sort_keys=True).encode()).hexdigest(),
            'baseline_version': baseline['version'], 'candidate_version': candidate['version'],
            'cases': len(cases), 'scored_fields': total,
            'baseline_label_agreement': before / total, 'candidate_label_agreement': after / total,
            'regressions': regressions, 'improvements': improvements,
            'minimum_cases_met': enough,
            'eligible_for_human_review': enough and after > before and not regressions,
            'automatic_promotion': False,
            'caveat': 'Correction cases are selection-biased. This is exact label agreement on the supplied held-out set, not general recognition accuracy.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dataset')
    parser.add_argument('baseline')
    parser.add_argument('candidate')
    args = parser.parse_args()
    with open(args.dataset) as handle: dataset = json.load(handle)
    with open(args.baseline) as handle: baseline = json.load(handle)
    with open(args.candidate) as handle: candidate = json.load(handle)
    print(json.dumps(evaluate(dataset, baseline, candidate), indent=2))
