import pytest
from app.services.item_search import score_item

@pytest.mark.parametrize('query', ['PN-F157', 'PNF157', 'F157', '000113', 'M4', 'black copper'])
def test_numeric_identifiers_and_missing_keywords_are_not_guessed(query):
    row = {'name': 'Black M3 steel spring', 'part_number': 'PN-F156', 'barcode': '000112'}
    assert score_item(row, query) == 0

@pytest.mark.parametrize('query', ['adaptor', 'adapters', 'adpater', 'adater'])
def test_common_word_variants(query):
    assert score_item({'name': 'HDMI adapter'}, query) > 0


def test_ranks_exact_name_and_identifier_ahead_of_spelling_candidate():
    assert score_item({'part_number': 'PN-F156'}, 'pnf156') == 1000
    assert score_item({'name': 'adapter'}, 'adapter') > score_item({'name': 'adaptez'}, 'adapter')
    assert score_item({'name': 'spring', 'notes': 'black'}, 'black spring') > 0
    assert score_item({'name': 'spring'}, 'black spring') == 0
    assert score_item({'name': 'bolt'}, '%,(),') == 0
    assert score_item({'name': 'bolt', 'import_data': {'filename': 'secret.csv'}}, 'secret') == 0
