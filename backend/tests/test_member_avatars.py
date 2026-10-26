from types import SimpleNamespace as NS
from unittest.mock import Mock, patch
import pytest
from app.api.routes import collaboration


@pytest.mark.parametrize('path,expected', [('member/avatar.png', 'signed'), ('other/avatar.png', ''), ('https://foreign.test/photo.jpg', ''), (None, '')])
def test_authorized_roster_uses_only_each_members_saved_photo(path, expected):
    query = Mock()
    for method in ('select', 'in_'): getattr(query, method).return_value = query
    query.execute.return_value.data = [{'id': 'member', 'display_name': 'Ada', 'avatar_path': path, 'avatar_color': '#123456', 'private_field': 'SECRET'}, {'id': 'unrequested', 'avatar_path': 'unrequested/avatar.jpg'}]
    db = Mock(); db.table.return_value = query
    with patch.object(collaboration, 'get_supabase_raw', return_value=db), patch('app.services.storage.create_profile_photo_signed_url', return_value='signed') as sign:
        result = collaboration.members_with_names([{'user_id': 'member', 'role': 'viewer'}])
    assert result == [{'user_id': 'member', 'role': 'viewer', 'display_name': 'Ada', 'avatar_url': expected, 'avatar_color': '#123456'}]
    assert sign.call_count == bool(expected)
    assert 'avatar_path' not in result[0] and 'SECRET' not in str(result)
    query.in_.assert_called_once_with('id', ['member'])


def test_missing_or_unavailable_saved_photo_does_not_hide_the_roster():
    query = Mock()
    for method in ('select', 'in_'): getattr(query, method).return_value = query
    query.execute.return_value.data = [{'id': 'member', 'first_name': 'Ada', 'last_name': 'Lovelace', 'avatar_path': 'member/avatar.jpg'}]
    db = Mock(); db.table.return_value = query
    with patch.object(collaboration, 'get_supabase_raw', return_value=db), patch('app.services.storage.create_profile_photo_signed_url', side_effect=RuntimeError('PRIVATE')):
        rows = collaboration.members_with_names([{'user_id': 'member'}, {'user_id': 'new'}])
    assert rows[0]['display_name'] == 'Ada Lovelace' and rows[0]['avatar_url'] == ''
    assert rows[1]['display_name'] == 'Member' and 'PRIVATE' not in str(rows)
