from fastapi import APIRouter

from app.api.routes.inventory import router as inventory_router
from app.api.routes.billing import router as billing_router

api_router = APIRouter()
api_router.include_router(inventory_router)
api_router.include_router(billing_router)
