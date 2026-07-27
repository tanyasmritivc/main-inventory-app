from fastapi import APIRouter

from app.api.routes.items import router as items_router
from app.api.routes.ai import router as ai_router
from app.api.routes.imports import router as imports_router
from app.api.routes.documents import router as documents_router
from app.api.routes.activity import router as activity_router
from app.api.routes.sharing import router as sharing_router
from app.api.routes.checkouts import router as checkouts_router
from app.api.routes.profile import router as profile_router
from app.api.routes.usage import router as usage_router
from app.api.routes.billing import router as billing_router
from app.api.routes.stripe_routes import router as stripe_router
from app.api.routes.conversations import router as conversations_router

api_router = APIRouter()
api_router.include_router(items_router)
api_router.include_router(ai_router)
api_router.include_router(imports_router)
api_router.include_router(documents_router)
api_router.include_router(activity_router)
api_router.include_router(sharing_router)
api_router.include_router(checkouts_router)
api_router.include_router(profile_router)
api_router.include_router(usage_router)
api_router.include_router(billing_router)
api_router.include_router(stripe_router)
api_router.include_router(conversations_router)
