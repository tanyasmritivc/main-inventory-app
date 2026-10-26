"""Developer-only, privacy-filtered report from an authorized export; no training.

python backend/tools/response_feedback_report.py --input feedback.json --output report.json
Input: {"eligible_responses":N,"ratings":[...]} from a secure operator query.
Never publish raw input. Output excludes comments, transcripts and identity fields.
"""
import argparse
import json
import os
from pathlib import Path
from app.services.response_feedback_eval import summarize, compare_fixed_cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input')
    parser.add_argument('--baseline')
    parser.add_argument('--candidate')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.baseline and args.candidate and not args.input:
        report = compare_fixed_cases(json.loads(Path(args.baseline).read_text()), json.loads(Path(args.candidate).read_text()))
    elif args.input and not args.baseline and not args.candidate:
        raw = json.loads(Path(args.input).read_text())
        report = summarize(raw['ratings'], raw['eligible_responses'])
    else: parser.error('Choose --input OR --baseline and --candidate')
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as out: json.dump(report, out, indent=2)
    if report.get('passed') is False: raise SystemExit(2)


if __name__ == '__main__': main()
