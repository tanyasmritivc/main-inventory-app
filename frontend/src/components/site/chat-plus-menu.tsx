"use client";
import Link from "next/link";
import {
  Plus,
  Sparkles,
  Paperclip,
  Boxes,
  MessageSquare,
  Image as ImageIcon,
  Camera,
  Folder,
  Table,
  Barcode,
  MapPin,
  FileText,
  LinkIcon,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
  DropdownMenuItem,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
} from "@/components/ui/dropdown-menu";
import styles from "./chat-sources.module.css";
export type ChatChoice =
  | "auto_extract"
  | "library"
  | "camera"
  | "file"
  | "spreadsheet"
  | "barcode"
  | "space"
  | "item"
  | "project"
  | "document";
export function ChatPlusMenu({
  disabled,
  onSelect,
}: {
  disabled: boolean;
  onSelect: (choice: ChatChoice) => void;
}) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          className={styles.plus}
          disabled={disabled}
          aria-label="Add to chat"
        >
          <Plus size={20} strokeWidth={1.5} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        side="top"
        align="start"
        sideOffset={10}
        collisionPadding={12}
        className={styles.menu}
      >
        <DropdownMenuItem onSelect={() => onSelect("auto_extract")}>
          <Sparkles />
          Auto Extract
        </DropdownMenuItem>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>
            <Paperclip />
            Attach
          </DropdownMenuSubTrigger>
          <DropdownMenuSubContent className={styles.menu}>
            <DropdownMenuItem onSelect={() => onSelect("library")}>
              <ImageIcon />
              Photo library
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("camera")}>
              <Camera />
              Take photo
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("file")}>
              <Folder />
              Choose files
            </DropdownMenuItem>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>
            <Boxes />
            Inventory tools
          </DropdownMenuSubTrigger>
          <DropdownMenuSubContent className={styles.menu}>
            <DropdownMenuItem onSelect={() => onSelect("spreadsheet")}>
              <Table />
              Import inventory
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("barcode")}>
              <Barcode />
              Scan barcode
            </DropdownMenuItem>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
        <DropdownMenuSub>
          <DropdownMenuSubTrigger>
            <MessageSquare />
            Add context
          </DropdownMenuSubTrigger>
          <DropdownMenuSubContent className={styles.menu}>
            <DropdownMenuItem onSelect={() => onSelect("space")}>
              <MapPin />
              Spaces
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("item")}>
              <Boxes />
              Items
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("project")}>
              <Folder />
              Projects
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => onSelect("document")}>
              <FileText />
              Documents and notes
            </DropdownMenuItem>
            <DropdownMenuItem asChild>
              <Link href="/docs/api#ai-assistants">
                <LinkIcon />
                Connections
              </Link>
            </DropdownMenuItem>
          </DropdownMenuSubContent>
        </DropdownMenuSub>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
