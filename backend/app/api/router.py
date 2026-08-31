from fastapi import APIRouter

from app.api.routes.items import router as items_router
from app.api.routes.ai import router as ai_router
from app.api.routes.imports import router as imports_router
from app.api.routes.documents import router as documents_router
from app.api.routes.activity import router as activity_router
from app.api.routes.sharing import router as sharing_router
from app.api.routes.checkouts import router as checkouts_router
from app.api.routes.profile import router as profile_router
from app.api.routes.spaces import router as spaces_router
from app.api.routes.bins import router as bins_router
from app.api.routes.usage import router as usage_router
from app.api.routes.billing import router as billing_router
# stripe_routes.py (old /stripe/* endpoints) is intentionally NOT mounted — superseded by billing.py
from app.api.routes.conversations import router as conversations_router
from app.api.routes.me import router as me_router
from app.api.routes.teams import router as teams_router
from app.api.routes.licenses import router as licenses_router
from app.api.routes.project_kits import router as project_kits_router
from app.api.routes.team_board import router as team_board_router
from app.api.routes.team_workspace import router as team_workspace_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.push import router as push_router

api_router = APIRouter()
api_router.include_router(me_router)
api_router.include_router(items_router)
api_router.include_router(ai_router)
api_router.include_router(imports_router)
api_router.include_router(documents_router)
api_router.include_router(activity_router)
api_router.include_router(sharing_router)
api_router.include_router(checkouts_router)
api_router.include_router(profile_router)
api_router.include_router(spaces_router)
api_router.include_router(bins_router)
api_router.include_router(usage_router)
api_router.include_router(billing_router)
api_router.include_router(conversations_router)
api_router.include_router(teams_router)
api_router.include_router(licenses_router)
api_router.include_router(project_kits_router)
api_router.include_router(team_board_router)
api_router.include_router(team_workspace_router)
api_router.include_router(notifications_router)
api_router.include_router(push_router)
