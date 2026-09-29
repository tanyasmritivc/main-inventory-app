from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from app.api.routes.workspaces import workspace_detail


def _chain(data, count=None):
    chain = MagicMock()
    for method in ("select", "eq", "limit", "order", "in_"):
        getattr(chain, method).return_value = chain
    chain.execute.return_value = SimpleNamespace(data=data, count=count)
    return chain


def test_workspace_detail_rejects_nonmember_before_reading_content():
    client = MagicMock()
    client.table.return_value = _chain([])
    with patch("app.api.routes.workspaces.get_supabase_admin", return_value=client):
        with pytest.raises(HTTPException) as error:
            workspace_detail("workspace-1", SimpleNamespace(user_id="outside"))
    assert error.value.status_code == 404
    client.table.assert_called_once_with("workspace_members")


def test_workspace_detail_returns_member_roles_and_exact_counts():
    client = MagicMock()
    client.table.side_effect = [
        _chain([{"role": "editor"}]),
        _chain([{"workspace_id": "workspace-1", "name": "Workshop"}]),
        _chain([{"user_id": "member-1", "role": "editor", "joined_at": "now"}]),
        _chain([{"id": "member-1", "display_name": "Member name"}]),
        _chain([{"id": "space-1", "name": "Storage"}]),
        _chain([], count=4),
        _chain([], count=2),
    ]
    with patch("app.api.routes.workspaces.get_supabase_admin", return_value=client):
        result = workspace_detail("workspace-1", SimpleNamespace(user_id="member-1"))
    assert result["workspace"]["object_count"] == 4
    assert result["members"][0]["display_name"] == "Member name"
    assert result["places"][0]["object_count"] == 2
