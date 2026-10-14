from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes.shopify import membership, connection, enabled
from app.services.shopify_edits import call

router = APIRouter(tags=["shopify"])


@router.get("/teams/{team_id}/shopify/{connection_id}/migration")
def progress(team_id: UUID, connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    membership(team_id, user.user_id)
    settings = enabled()
    if not settings.merchant_migration_enabled or not settings.physical_memory_enabled:
        raise HTTPException(503, "Guided merchant setup is not enabled yet.")
    connection(team_id, connection_id)
    return call("adoption_report", team=str(team_id), connection=str(connection_id), actor=user.user_id)
