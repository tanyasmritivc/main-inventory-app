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
  // Never fall back to organization or legacy account scope while selection changes.
  if (activeInventory() !== inventory || inventory.can_open === false) return null;
  return (
    <Dialog.Root open={open} onOpenChange={setOpen} modal={false}>
      <Dialog.Trigger asChild>
        <button className={styles.launcher} aria-label={`Ask FindEZ about ${inventory.name}`}>
          <MessageCircle size={18} aria-hidden="true" /> Ask FindEZ
        </button>
      </Dialog.Trigger>
      <Dialog.Content className={styles.panel} onInteractOutside={event => event.preventDefault()}>
        <header className={styles.header}>
          <div>
            <Dialog.Title>Ask FindEZ</Dialog.Title>
            <Dialog.Description>Only in {inventory.name}</Dialog.Description>
          </div>
          <Dialog.Close className={styles.close} aria-label="Close contextual chat"><X size={19} /></Dialog.Close>
        </header>
        <div className={styles.content}>
          <AssistClient contextual title={`Ask about ${inventory.name}`} />
        </div>
      </Dialog.Content>
    </Dialog.Root>
  );
}
