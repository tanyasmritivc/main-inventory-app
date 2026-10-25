from fastapi import APIRouter

from app.api.routes.items import router as items_router
from app.api.routes.inventory import router as inventory_router
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
from app.api.routes.email import router as email_router
from app.api.routes.project_kits import router as project_kits_router
from app.api.routes.team_board import router as team_board_router
from app.api.routes.team_workspace import router as team_workspace_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.push import router as push_router
from app.api.routes.api_v1 import router as api_v1_router
from app.api.routes.review import router as review_router
from app.api.routes.invitations import router as invitations_router

from app.api.routes.onboarding import router as onboarding_router

api_router = APIRouter()
api_router.include_router(me_router)
api_router.include_router(items_router)
api_router.include_router(inventory_router)
api_router.include_router(ai_router)
api_router.include_router(imports_router)
from app.api.routes.connectors import router as connectors_router
api_router.include_router(connectors_router)
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
api_router.include_router(email_router)
api_router.include_router(project_kits_router)
api_router.include_router(team_board_router)
api_router.include_router(team_workspace_router)
api_router.include_router(notifications_router)
api_router.include_router(push_router)
api_router.include_router(api_v1_router)
api_router.include_router(review_router)
api_router.include_router(invitations_router)

api_router.include_router(onboarding_router)

from app.api.routes.memory import router as memory_router
api_router.include_router(memory_router)

# The same inventory journeys run behind an explicit, server-validated context.
# Account, collaboration administration and public integration APIs stay outside.
from app.api.routes.inventory_workspaces import router as workspace_selection_router, scoped_router
api_router.include_router(workspace_selection_router)
from app.api.routes.collaboration import router as collaboration_router
api_router.include_router(collaboration_router)
from app.api.routes.access_invitations import router as access_invitations_router
api_router.include_router(access_invitations_router)
from app.api.routes.workspace_directory import router as directory_router
api_router.include_router(directory_router)
for scoped_feature_router in (
    items_router, inventory_router, ai_router, imports_router, connectors_router, documents_router,
    activity_router, checkouts_router, spaces_router, bins_router,
    conversations_router, project_kits_router, review_router, sharing_router,
):
    scoped_router.include_router(scoped_feature_router)
api_router.include_router(scoped_router)

from app.api.routes.private_images import router as private_images_router
api_router.include_router(private_images_router)

from app.api.routes.world_chat import router as world_chat_router
api_router.include_router(world_chat_router)

from app.api.routes.personalization import router as personalization_router
api_router.include_router(personalization_router)
