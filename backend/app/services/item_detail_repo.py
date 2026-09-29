from app.services.item_relationships_repo import authorized_item
from app.services.supabase_client import get_supabase_admin


def get_item_detail(*, user_id: str, item_id: str,
                    selected_workspace_id: str | None = None) -> dict:
    item = authorized_item(user_id=user_id, item_id=item_id,
                           selected_workspace_id=selected_workspace_id)
    client = get_supabase_admin()
    workspace_name = None
    if item.get("workspace_id"):
        teams = (
            client.table("workspaces" if selected_workspace_id else "teams").select("name")
            .eq("workspace_id" if selected_workspace_id else "team_id", item["workspace_id"])
            .limit(1).execute().data or []
        )
        workspace_name = teams[0]["name"] if teams else None
    space_name = item.get("location")
    if item.get("space_id"):
        spaces = (
            client.table("spaces").select("name")
            .eq("id", item["space_id"]).limit(1).execute().data or []
        )
        if spaces:
            space_name = spaces[0]["name"]
    bin_name = None
    if item.get("bin_id"):
        bins = (
            client.table("bins").select("name,space_id")
            .eq("id", item["bin_id"]).limit(1).execute().data or []
        )
        if bins and bins[0]["space_id"] == item.get("space_id"):
            bin_name = bins[0]["name"]
    return {
        **item,
        "workspace_name": workspace_name,
        "space_name": space_name,
        "bin_name": bin_name,
    }
