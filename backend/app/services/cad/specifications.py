"""Conservative nominal specification checks, never engineering certification."""
import re
from decimal import Decimal, InvalidOperation

DIMENSIONS={'length_mm','diameter_mm','thread_pitch_mm','inner_diameter_mm','outer_diameter_mm','thickness_mm','width_mm','height_mm'}
TEXT={'material','finish','head_type','thread_direction','thread_standard','strength_grade','part_type','thread_fit'}
KEYS=DIMENSIONS|TEXT


def dimension(value):
    if isinstance(value,bool): return None
    match=re.fullmatch(r'\s*([0-9]+(?:\.[0-9]+)?)\s*(mm|cm|in|inch|inches)?\s*',str(value).casefold())
    if not match:return None
    try:
        result=Decimal(match[1])*{'mm':Decimal(1),'cm':Decimal(10),'in':Decimal('25.4'),'inch':Decimal('25.4'),'inches':Decimal('25.4'),None:Decimal(1)}[match[2]]
        return result if result.is_finite() and 0<result<=1000000 else None
    except InvalidOperation:return None


def check(required, actual):
    conflicts=[];unknown=[]
    for key,value in (required or {}).items():
        if key not in KEYS:unknown.append(key);continue
        other=(actual or {}).get(key)
        a=dimension(value) if key in DIMENSIONS else ' '.join(str(value).casefold().split())
        b=dimension(other) if key in DIMENSIONS else ' '.join(str(other or '').casefold().split())
        if a is None or not b:unknown.append(key)
        elif a!=b:conflicts.append(key)
    return conflicts,unknown
