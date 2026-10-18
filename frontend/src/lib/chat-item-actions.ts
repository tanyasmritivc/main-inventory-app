import { accountRequest } from "@/lib/account-request";
import { activeInventory, assertInventory, inventoryApiPath } from "@/lib/inventory-selection";

import { parseChatItemAction, type ChatItemAction } from "./chat-item-action-model";
export { parseChatItemAction, type ChatItemAction } from "./chat-item-action-model";

export async function decideChatItemAction(accountId: string, action: ChatItemAction, decision: "confirm" | "cancel", signal: AbortSignal) {
  const inventory = activeInventory();
  if (!inventory || inventory.accountId !== accountId || inventory.inventory_id !== action.inventoryId)
    throw new Error("Open the inventory containing this action before continuing.");
  if (decision === "confirm" && !inventory.can_edit) throw new Error("You have view-only access to this inventory.");
  const result = await accountRequest<{ action: unknown; assistant_message?: string; reply_id?: string; answer_error?: string }>(accountId,
    inventoryApiPath(`/ai_actions/${encodeURIComponent(action.id)}`, inventory), {
      method: "POST", body: JSON.stringify({ decision }), signal,
    });
  assertInventory(inventory);
  const updated = parseChatItemAction(result.action);
  if (!updated || updated.id !== action.id || updated.inventoryId !== inventory.inventory_id || updated.status === "pending")
    throw new Error("The action receipt could not be verified. Retry this same card.");
  return { action: updated, content: result.assistant_message, replyId: result.reply_id, answerError: result.answer_error };
}
