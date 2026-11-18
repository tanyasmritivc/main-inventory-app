"use client";
import { useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { MessageCircle, X } from "lucide-react";
import { AssistClient } from "./assist-client";
import { activeInventory, type InventorySelection } from "@/lib/inventory-selection";
import styles from "./context-chat.module.css";

const pages = /^\/(?:inventory|spaces|documents|activity|review|restock|checkout|project-kits|collections|labels)(?:\/|$)/;
export function hasContextChat(path: string) { return pages.test(path); }

export function ContextChat({ inventory }: { inventory: InventorySelection }) {
  const [open, setOpen] = useState(false);
  // Derive the organization from this tab's authorized selection, never a remembered world.
  if (activeInventory() !== inventory || inventory.can_open === false) return null;
  const worldId = inventory.workspace.world_key || inventory.workspace.organization_id || undefined;
  const scopeName = inventory.workspace.organization_name || (worldId === "personal" ? "Personal" : inventory.workspace.name);
  return (
    <Dialog.Root open={open} onOpenChange={setOpen} modal={false}>
      <Dialog.Trigger asChild>
        <button className={styles.launcher} aria-label={`Ask FindEZ about ${worldId ? scopeName : inventory.name}`}>
          <MessageCircle size={18} aria-hidden="true" /> Ask FindEZ
        </button>
      </Dialog.Trigger>
      <Dialog.Content className={styles.panel} onInteractOutside={event => event.preventDefault()}>
        <header className={styles.header}>
          <div>
            <Dialog.Title>Ask FindEZ</Dialog.Title>
            <Dialog.Description>{worldId ? `Across accessible Spaces in ${scopeName}` : `Only in ${inventory.name}`}</Dialog.Description>
          </div>
          <Dialog.Close className={styles.close} aria-label="Close contextual chat"><X size={19} /></Dialog.Close>
        </header>
        <div className={styles.content}>
          <AssistClient contextual worldId={worldId} title={`Ask about ${worldId ? scopeName : inventory.name}`} />
        </div>
      </Dialog.Content>
    </Dialog.Root>
  );
}
