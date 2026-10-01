import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import service_unavailable
from app.schemas.inventory import (
    ResolveReviewItemRequest,
    ResolveReviewItemResponse,
    ReviewItemResponse,
    ReviewItemsResponse,
    ReviewItemUpdate,
)
from app.services.documents_repo import create_activity
from app.services.limits import check_item_limit
from app.services.review_queue import (
    ReviewItemConflict,
    ReviewItemNotFound,
    dismiss_review_item,
    list_review_items,
    resolve_review_item,
    update_review_item,
)
from app.services.spaces_repo import SpaceLimitExceeded


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/review-items", tags=["review"])


@router.get("", response_model=ReviewItemsResponse)
def review_items_route(
    limit: int = Query(default=100, ge=1, le=200),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ReviewItemsResponse:
    try:
        items, count = list_review_items(user_id=user.user_id, limit=limit)
        return ReviewItemsResponse(items=items, pending_count=count)
    except Exception as exc:
        logger.exception("Could not load review queue")
        raise service_unavailable("Review items could not be loaded. Try again.") from exc


@router.patch("/{review_id}", response_model=ReviewItemResponse)
def update_review_item_route(
    review_id: UUID,
    payload: ReviewItemUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ReviewItemResponse:
    try:
        item = update_review_item(
            user_id=user.user_id,
            review_id=str(review_id),
            updates=payload.model_dump(exclude_unset=True),
        )
        return ReviewItemResponse(review_item=item)
    except ReviewItemNotFound as exc:
        raise HTTPException(404, "Review item not found") from exc
    except ReviewItemConflict as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        logger.exception("Could not update review item")
        raise service_unavailable("Review item could not be updated. Try again.") from exc


@router.post("/{review_id}/resolve", response_model=ResolveReviewItemResponse)
def resolve_review_item_route(
    review_id: UUID,
    payload: ResolveReviewItemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ResolveReviewItemResponse:
    limit = check_item_limit(user.user_id)
    if not limit["allowed"]:
        raise HTTPException(
            403,
            detail={
                "error": "item_limit_reached",
                "message": f"Item limit of {limit['limit']} reached.",
                "current": limit["current"],
                "limit": limit["limit"],
                "upgrade_required": True,
            },
        )
    try:
        item = resolve_review_item(
            user_id=user.user_id,
            review_id=str(review_id),
            item=payload.model_dump(),
        )
        try:
            create_activity(
                user_id=user.user_id,
                summary=f"Reviewed and saved {item.get('name') or 'an item'}",
                metadata={"type": "review_resolved", "review_id": str(review_id)},
            )
        except Exception:
            logger.exception("Failed to write review resolution activity")
        return ResolveReviewItemResponse(item=item)
    except ReviewItemNotFound as exc:
        raise HTTPException(404, "Review item not found") from exc
    except ReviewItemConflict as exc:
        raise HTTPException(409, str(exc)) from exc
    except SpaceLimitExceeded as exc:
        raise HTTPException(403, "FREE_TIER_SPACE_LIMIT") from exc
    except Exception as exc:
        logger.exception("Could not resolve review item")
        raise service_unavailable("Review item could not be saved. Try again.") from exc


@router.delete("/{review_id}", response_model=ReviewItemResponse)
def dismiss_review_item_route(
    review_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ReviewItemResponse:
    try:
        item = dismiss_review_item(user_id=user.user_id, review_id=str(review_id))
        try:
            create_activity(
                user_id=user.user_id,
                summary="Dismissed an uncertain capture",
                metadata={"type": "review_dismissed", "review_id": str(review_id)},
            )
        except Exception:
            logger.exception("Failed to write review dismissal activity")
        return ReviewItemResponse(review_item=item)
    except ReviewItemNotFound as exc:
        raise HTTPException(404, "Review item not found") from exc
    except Exception as exc:
        logger.exception("Could not dismiss review item")
        raise service_unavailable("Review item could not be dismissed. Try again.") from exc
