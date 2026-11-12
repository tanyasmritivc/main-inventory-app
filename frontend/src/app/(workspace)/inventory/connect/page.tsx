import { redirect } from "next/navigation";

// Preserve bookmarks; Connections no longer needs an active inventory.
export default function Page() { redirect("/settings/connections"); }
