"""Public activity labels, never model reasoning or tool arguments."""


def tool_status(name):
    if name in {"world_search", "world_inventory", "world_query"}:
        return "Searching your saved items…"
    if name in {"world_spaces", "world_structure"}:
        return "Checking your Spaces…"
    if name in {
        "world_draft_items",
        "world_add_items",
        "world_create_task",
        "world_refine_capture",
    }:
        return "Preparing your inventory draft…"
    if name in {"world_edit_item", "world_adjust_quantity", "world_move_item"}:
        return "Updating the requested item…"
    if name in {"world_projects", "world_project_readiness"}:
        return "Checking project requirements…"
    if name in {"world_tracking", "world_reorders"}:
        return "Checking stock and reminders…"
    if name == "world_attach_item_photo":
        return "Finding the item for your photo…"
    return "Checking the details…"


# These describe preparing a tool request, not executing it or completing a save.
def planning_status(name):
    if name in {"world_draft_items", "world_add_items", "world_create_task", "world_refine_capture"}:
        return "Building your item draft..."
    if name == "world_structure":
        return "Planning your Spaces..."
    if name in {"world_search", "world_inventory", "world_query", "world_spaces"}:
        return "Preparing an inventory lookup..."
    if name in {"world_edit_item", "world_adjust_quantity", "world_move_item", "world_delete_items"}:
        return "Preparing the requested changes..."
    return "Preparing the next step..."


def response_status(trace):
    for entry in trace:
        result = entry.get('result')
        if not isinstance(result, dict):
            continue
        for key in ('world_action', 'pending_action', 'capture_draft'):
            action = result.get(key)
            if isinstance(action, dict) and action.get('status') in ('pending', 'draft'):
                return "Writing your draft summary..."
    if trace:
        return "Working through the results..."
    return "Thinking through your request..."
