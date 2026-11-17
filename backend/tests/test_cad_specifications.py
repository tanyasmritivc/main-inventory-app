from app.services.cad.specifications import check
from app.services.cad.comparison import compare
from app.services.cad import corrections
from backend.tests.test_cad_prototype import snapshot, stock


def test_nominal_unit_equivalence_requires_known_fields():
    assert check({'length_mm':'25.4','material':'Stainless Steel'},{'length_mm':'1 in','material':' stainless  steel '})==([],[])
    conflicts,unknown=check({'length_mm':'16','finish':'zinc','load_rating':'10'},{'length_mm':'12'})
    assert conflicts==['length_mm'] and unknown==['finish','load_rating']


def test_exact_part_number_cannot_override_conflicting_variant():
    value=snapshot();part=next(d for d in value.definitions if d.procurement_policy=='purchase')
    part.specifications={'length_mm':'16','material':'titanium'}
    item=stock(6);item['specifications']={'length_mm':'12','material':'steel'}
    result=compare(value,[item],[],[])
    line=next(r for r in result['items'] if r['key']==part.key)
    assert line['assigned']==0 and line['status']=='needs_review'
    assert set(line['specification_issues'][0]['conflicts'])=={'length_mm','material'}


def test_absent_specs_remain_reviewable_and_saved_decision_invalidates_on_change():
    value=snapshot();part=next(d for d in value.definitions if d.procurement_policy=='purchase');part.specifications={'length_mm':'16'}
    item=stock(6);result=compare(value,[item],[],[])
    assert result['summary']['covered_units']==0 and result['summary']['review_lines']>0
    before=corrections.item_identity(item);item['specifications']={'length_mm':'12'}
    assert corrections.item_identity(item)!=before
    identity=corrections.identity(part.model_dump());part.specifications={'length_mm':'12'}
    assert corrections.identity(part.model_dump())!=identity
