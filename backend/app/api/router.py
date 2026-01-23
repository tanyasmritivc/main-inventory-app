from fastapi import APIRouter

from app.api.routes.inventory import router as inventory_router

api_router = APIRouter()
api_router.include_router(inventory_router)
