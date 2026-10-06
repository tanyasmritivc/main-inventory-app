"use client";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { FileText, FileUp, Plus, RefreshCw } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { useApiSession } from "@/lib/use-api-session";
import {
  apiBase,
  itemDisplayName,
  type InventoryItem,
  type Space,
} from "@/lib/api";
import { accountRequest, accountToken } from "@/lib/account-request";
import {
  documentKind,
  ownedNotePath,
  trustedDocumentUrl,
  type DocumentEntry,
} from "@/lib/documents";
import { userFacingError } from "@/lib/user-facing-error";
export function DocumentsClient({
  initialItem = "",
}: {
  initialItem?: string;
}) {
  const { accountId } = useApiSession();
  return (
    <DocumentsClientWorkspace
      key={accountId || "signed-out"}
      initialItem={initialItem}
    />
  );
}
function DocumentsClientWorkspace({
  initialItem = "",
}: {
  initialItem?: string;
}) {
  const { accountId, error: sessionError } = useApiSession(),
    { confirmAction, promptValue } = useAppDialog();
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const generation = useRef(0);
  const [docs, setDocs] = useState<DocumentEntry[]>([]),
    [items, setItems] = useState<InventoryItem[]>([]),
    [spaces, setSpaces] = useState<Space[]>([]),
    [itemFilter, setItemFilter] = useState(initialItem),
    [filter, setFilter] = useState("all"),
    [search, setSearch] = useState(""),
    [noteIndex, setNoteIndex] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true),
    [working, setWorking] = useState(false),
    [error, setError] = useState(""),
    [message, setMessage] = useState("");
  const [note, setNote] = useState<{
      doc?: DocumentEntry;
      text: string;
      title: string;
    } | null>(null),
    [linking, setLinking] = useState<DocumentEntry | null>(null),
    [linkId, setLinkId] = useState(""),
    [summary, setSummary] = useState<{ title: string; text: string } | null>(
      null,
    ),
    [importFile, setImportFile] = useState<File | null>(null),
    [importSpace, setImportSpace] = useState("");
  const fileInput = useRef<HTMLInputElement>(null),
    importInput = useRef<HTMLInputElement>(null);
  const origins = [process.env.NEXT_PUBLIC_SUPABASE_URL || "", apiBase()];
  async function openUrl(doc: DocumentEntry, account: string) {
    const result = await accountRequest<{ url: string }>(
      account,
      `/documents/open?${new URLSearchParams({ storage_path: doc.storage_path })}`,
    );
    const url = trustedDocumentUrl(result.url, account, origins);
    if (!url)
      throw new Error(
        "This document could not be opened safely. Please refresh and try again.",
      );
    return url;
  }
  async function readNote(doc: DocumentEntry, account: string) {
    const url = await openUrl(doc, account),
      response = await fetch(url);
    if (
      !response.ok ||
      Number(response.headers.get("content-length") ?? 0) > 256 * 1024
    )
      throw new Error(
        "This note could not be loaded, or it is too large to edit here.",
      );
    const text = await response.text();
    if (text.length > 256 * 1024)
      throw new Error("This note is too large to edit here.");
    await accountToken(account);
    return text;
  }
  const load = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      ticket = ++generation.current;
    setLoading(true);
    setError("");
    setDocs([]);
    setNoteIndex({});
    try {
      const result = await accountRequest<{ documents: DocumentEntry[] }>(
        account,
        `/documents?${new URLSearchParams({ limit: "200", ...(itemFilter ? { item_id: itemFilter } : {}) })}`,
      );
      if (owner.current !== account || ticket !== generation.current) return;
      setDocs(result.documents);
      setLoading(false);
      // Bound concurrent signed-URL reads; note text remains account-local memory.
      const notes = result.documents.filter((d) => documentKind(d) === "notes"),
        index: Record<string, string> = {};
      for (let i = 0; i < notes.length; i += 3) {
        if (owner.current !== account || ticket !== generation.current) return;
        await Promise.all(
          notes.slice(i, i + 3).map(async (doc) => {
            try {
              index[doc.storage_path] = await readNote(doc, account);
            } catch {
              /* An unreadable note remains listed and raises an error when opened. */
            }
          }),
        );
        if (owner.current === account && ticket === generation.current)
          setNoteIndex({ ...index });
      }
    } catch (e) {
      if (owner.current === account && ticket === generation.current)
        setError(userFacingError(e, "Could not load documents."));
    } finally {
      if (owner.current === account && ticket === generation.current)
        setLoading(false);
    }
    // The configured origins and request helpers are stable for this deployment.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [accountId, itemFilter]);
  useEffect(() => {
    setNote(null);
    setLinking(null);
    setSummary(null);
    setImportFile(null);
    void load();
    return () => {
      generation.current++;
    };
  }, [load]);
  useEffect(() => {
    if (!accountId) return;
    const account = accountId;
    setItems([]);
    setSpaces([]);
    void Promise.allSettled([
      accountRequest<{ items: InventoryItem[] }>(account, "/search_items", {
        method: "POST",
        body: { query: "" },
      }),
      accountRequest<Space[] | { spaces: Space[] }>(account, "/spaces"),
    ]).then(([inventory, locations]) => {
      if (owner.current !== account) return;
      if (inventory.status === "fulfilled") setItems(inventory.value.items);
      if (locations.status === "fulfilled")
        setSpaces(
          Array.isArray(locations.value)
            ? locations.value
            : locations.value.spaces,
        );
    });
  }, [accountId]);
  async function perform(operation: (account: string) => Promise<void>) {
    if (!accountId || working) return;
    const account = accountId;
    setWorking(true);
    setError("");
    setMessage("");
    try {
      await operation(account);
    } catch (e) {
      if (owner.current === account)
        setError(
          userFacingError(e, "The document action could not be completed."),
        );
    } finally {
      if (owner.current === account) setWorking(false);
    }
  }
  function replace(doc: DocumentEntry) {
    setDocs((current) =>
      current.map((d) => (d.storage_path === doc.storage_path ? doc : d)),
    );
  }
  async function upload(file: File) {
    await perform(async (account) => {
      const form = new FormData();
      form.append("file", file);
      if (itemFilter) form.append("item_id", itemFilter);
      const result = await accountRequest<{ document: DocumentEntry }>(
        account,
        "/documents/upload",
        { method: "POST", body: form },
      );
      if (owner.current !== account) return;
      setDocs((current) => [
        result.document,
        ...current.filter(
          (d) => d.storage_path !== result.document.storage_path,
        ),
      ]);
      setMessage("Document uploaded.");
    });
  }
  async function saveNote() {
    if (!note || !note.text.trim()) {
      setError("Write something in your note before saving.");
      return;
    }
    const draft = note;
    await perform(async (account) => {
      let document = draft.doc;
      if (document) {
        if (
          !ownedNotePath(document.storage_path, account) ||
          documentKind(document) !== "notes"
        )
          throw new Error("This note does not belong to this account.");
        const token = await accountToken(account);
        const response = await fetch(
          `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/documents/${document.storage_path.split("/").map(encodeURIComponent).join("/")}`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${token}`,
              apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "",
              "Content-Type": "text/plain",
              "x-upsert": "true",
            },
            body: draft.text,
          },
        );
        if (!response.ok)
          throw new Error(
            "Your note could not be saved. Your draft is available to retry.",
          );
        await accountToken(account);
      } else {
        const form = new FormData();
        form.append(
          "file",
          new File([draft.text], `note-${crypto.randomUUID()}.txt`, {
            type: "text/plain",
          }),
        );
        if (itemFilter) form.append("item_id", itemFilter);
        const result = await accountRequest<{ document: DocumentEntry }>(
          account,
          "/documents/upload",
          { method: "POST", body: form },
        );
        document = result.document;
        if (owner.current !== account) return;
        setDocs((current) => [result.document, ...current]);
        setNote({ ...draft, doc: document }); // A failed rename retries the existing note, never another upload.
      }
      if (draft.title.trim() && draft.title.trim() !== document.filename) {
        const result = await accountRequest<{ document: DocumentEntry }>(
          account,
          "/documents/rename",
          {
            method: "PATCH",
            body: {
              storage_path: document.storage_path,
              display_name:
                draft.title
                  .trim()
                  .slice(0, 196)
                  .replace(/\.txt$/i, "") + ".txt",
            },
          },
        );
        document = result.document;
      }
      if (owner.current === account) {
        replace(document);
        setNoteIndex((current) => ({
          ...current,
          [document.storage_path]: draft.text,
        }));
        setNote(null);
        setMessage("Note saved.");
      }
    });
  }
  async function open(doc: DocumentEntry) {
    await perform(async (account) => {
      if (documentKind(doc) === "notes") {
        const text =
          noteIndex[doc.storage_path] ?? (await readNote(doc, account));
        if (owner.current === account)
          setNote({ doc, text, title: doc.filename.replace(/\.txt$/i, "") });
      } else {
        const url = await openUrl(doc, account);
        if (owner.current === account) {
          setSummary({ title: doc.display_name || doc.filename, text: "" });
          setOpenLink(url);
        }
      }
    });
  }
  const [openLink, setOpenLink] = useState("");
  async function rename(doc: DocumentEntry) {
    const name = await promptValue({
      title: "Rename document",
      label: "Name",
      initialValue: doc.display_name || doc.filename,
      confirmLabel: "Save",
    });
    if (!name?.trim()) return;
    await perform(async (account) => {
      const result = await accountRequest<{ document: DocumentEntry }>(
        account,
        "/documents/rename",
        {
          method: "PATCH",
          body: { storage_path: doc.storage_path, display_name: name.trim() },
        },
      );
      if (owner.current === account) replace(result.document);
    });
  }
  async function remove(doc: DocumentEntry) {
    if (
      !(await confirmAction({
        title: "Delete document?",
        message: `Delete ${doc.display_name || doc.filename}? This cannot be undone.`,
        confirmLabel: "Delete",
        danger: true,
      }))
    )
      return;
    await perform(async (account) => {
      await accountRequest(
        account,
        `/documents?${new URLSearchParams({ storage_path: doc.storage_path })}`,
        { method: "DELETE" },
      );
      if (owner.current === account) {
        setDocs((current) =>
          current.filter((d) => d.storage_path !== doc.storage_path),
        );
        setMessage("Document deleted.");
      }
    });
  }
  const shown = docs.filter(
    (d) =>
      (filter === "all" || documentKind(d) === filter) &&
      `${d.display_name || d.filename} ${noteIndex[d.storage_path] ?? ""}`
        .toLowerCase()
        .includes(search.toLowerCase()),
  );
  return (
    <section>
      <header className="workspace-heading">
        <div>
          <h1>Documents and notes</h1>
          <p>
            {docs.length} files and notes
            {itemFilter ? " attached to this item" : " in your account"}.
          </p>
        </div>
        <div className="workspace-actions">
          <button
            className="workspace-button"
            aria-label="Refresh documents"
            disabled={working}
            onClick={() => void load()}
          >
            <RefreshCw size={15} />
          </button>
          <button
            className="workspace-button"
            disabled={working}
            onClick={() => {
              setError("");
              setNote({ text: "", title: "" });
            }}
          >
            <Plus size={15} />
            New note
          </button>
          <button
            className="workspace-button"
            disabled={working}
            onClick={() => importInput.current?.click()}
          >
            Import inventory
          </button>
          <button
            className="workspace-button primary"
            disabled={working}
            onClick={() => fileInput.current?.click()}
          >
            <FileUp size={15} />
            Upload
          </button>
        </div>
      </header>
      <input
        ref={fileInput}
        type="file"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (file) void upload(file);
        }}
      />
      <input
        ref={importInput}
        type="file"
        hidden
        accept=".csv,.xls,.xlsx,.json"
        onChange={(e) => {
          setImportFile(e.target.files?.[0] ?? null);
          e.target.value = "";
        }}
      />
      {(error || sessionError) && (
        <div className="workspace-error" role="alert">
          {error || sessionError}
        </div>
      )}
      {message && (
        <p role="status" className="workspace-muted">
          {message}
        </p>
      )}
      <div className="workspace-actions">
        <input
          className="workspace-input"
          style={{ maxWidth: 400 }}
          aria-label="Search documents and note contents"
          placeholder="Search documents and note contents"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="workspace-input"
          style={{ width: 240 }}
          aria-label="Documents attached to item"
          value={itemFilter}
          onChange={(e) => setItemFilter(e.target.value)}
        >
          <option value="">All documents</option>
          {items.map((i) => (
            <option key={i.item_id} value={i.item_id}>
              {itemDisplayName(i)}
            </option>
          ))}
        </select>
      </div>
      <div className="workspace-chips">
        {["all", "notes", "pdfs", "images", "files"].map((f) => (
          <button
            className={filter === f ? "is-active" : ""}
            key={f}
            onClick={() => setFilter(f)}
          >
            {f === "all"
              ? "Everything"
              : f === "pdfs"
                ? "PDFs"
                : f[0].toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>
      <div className="workspace-section">
        {loading ? (
          <p role="status" className="workspace-muted">
            Loading documents…
          </p>
        ) : (
          shown.map((d) => (
            <div className="workspace-list-row" key={d.storage_path}>
              <span className="workspace-actions">
                <FileText size={19} />
                <span>
                  <button
                    type="button"
                    style={{
                      background: "transparent",
                      border: 0,
                      color: "inherit",
                      padding: 0,
                      textAlign: "left",
                    }}
                    onClick={() => void open(d)}
                    disabled={working}
                  >
                    <strong>{d.display_name || d.filename}</strong>
                  </button>
                  <small>
                    {documentKind(d) === "notes"
                      ? "Note"
                      : d.mime_type || "File"}
                    {d.created_at
                      ? ` · ${new Date(d.created_at).toLocaleDateString()}`
                      : ""}
                    {d.item_id ? " · Linked to item" : ""}
                  </small>
                </span>
              </span>
              <div className="workspace-actions">
                <button
                  className="workspace-button"
                  disabled={working}
                  onClick={() => void rename(d)}
                >
                  Rename
                </button>
                <button
                  className="workspace-button"
                  disabled={working}
                  onClick={() => {
                    setLinking(d);
                    setLinkId(d.item_id || itemFilter);
                  }}
                >
                  Link / unlink
                </button>
                <button
                  className="workspace-button"
                  disabled={working}
                  onClick={() =>
                    void perform(async (account) => {
                      const result = await accountRequest<{
                        assistant_message: string;
                      }>(account, "/ai_command", {
                        method: "POST",
                        body: {
                          message: `Summarize this document in a few short bullets. Document: "${d.filename}". storage_path: "${d.storage_path}".`,
                        },
                      });
                      if (owner.current === account) {
                        setOpenLink("");
                        setSummary({
                          title: d.filename,
                          text: result.assistant_message,
                        });
                      }
                    })
                  }
                >
                  Summarize
                </button>
                <button
                  className="workspace-button"
                  disabled={working}
                  onClick={() => void remove(d)}
                >
                  Delete
                </button>
              </div>
            </div>
          ))
        )}
        {!loading && !shown.length && !error && (
          <div className="workspace-card">
            <h2>
              {search
                ? "No matching documents or notes"
                : "Keep the details with your things"}
            </h2>
            <p className="workspace-muted">
              Upload a receipt or manual, or add a note. Link it to an item to
              find it again.
            </p>
          </div>
        )}
      </div>
      <Dialog
        open={!!note}
        onOpenChange={(open) => {
          if (!open && !working) setNote(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>{note?.doc ? "Edit note" : "New note"}</DialogTitle>
          <DialogDescription>
            Save a text note with your documents.
          </DialogDescription>
          <label htmlFor="note-title">Title</label>
          <input
            id="note-title"
            className="workspace-input"
            value={note?.title || ""}
            maxLength={196}
            disabled={working}
            onChange={(e) =>
              setNote((n) => (n ? { ...n, title: e.target.value } : n))
            }
          />
          <label htmlFor="note-text">Note</label>
          <textarea
            id="note-text"
            className="workspace-input"
            value={note?.text || ""}
            maxLength={256 * 1024}
            disabled={working}
            onChange={(e) =>
              setNote((n) => (n ? { ...n, text: e.target.value } : n))
            }
          />
          {error && (
            <p className="workspace-error" role="alert">
              {error}
            </p>
          )}
          <div className="workspace-actions">
            <button
              className="workspace-button"
              disabled={working}
              onClick={() => setNote(null)}
            >
              Cancel
            </button>
            <button
              className="workspace-button primary"
              disabled={working}
              onClick={() => void saveNote()}
            >
              {working ? "Saving…" : "Save note"}
            </button>
          </div>
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!linking}
        onOpenChange={(open) => {
          if (!open && !working) setLinking(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>Attach to an item</DialogTitle>
          <DialogDescription>{linking?.filename}</DialogDescription>
          <label htmlFor="document-link">Item</label>
          <select
            id="document-link"
            className="workspace-input"
            value={linkId}
            onChange={(e) => setLinkId(e.target.value)}
          >
            <option value="">No item (unlink)</option>
            {items.map((i) => (
              <option key={i.item_id} value={i.item_id}>
                {itemDisplayName(i)}
              </option>
            ))}
          </select>
          {error && <p role="alert">{error}</p>}
          <div className="workspace-actions">
            <button
              className="workspace-button primary"
              disabled={working}
              onClick={() =>
                void perform(async (account) => {
                  if (!linking) return;
                  const result = await accountRequest<{
                    document: DocumentEntry;
                  }>(account, "/documents/link", {
                    method: "PATCH",
                    body: {
                      storage_path: linking.storage_path,
                      item_id: linkId || null,
                    },
                  });
                  if (owner.current === account) {
                    replace(result.document);
                    if (itemFilter && linkId !== itemFilter)
                      setDocs((current) =>
                        current.filter(
                          (d) => d.storage_path !== linking.storage_path,
                        ),
                      );
                    setLinking(null);
                    setMessage(
                      linkId ? "Document linked." : "Document unlinked.",
                    );
                  }
                })
              }
            >
              Save link
            </button>
          </div>
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!summary}
        onOpenChange={(open) => {
          if (!open) {
            setSummary(null);
            setOpenLink("");
          }
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>{summary?.title}</DialogTitle>
          <DialogDescription>
            {openLink
              ? "Open the saved file in a new tab."
              : "Summary from FindEZ. Check the original document for accuracy."}
          </DialogDescription>
          {openLink ? (
            <a
              className="workspace-button primary"
              href={openLink}
              target="_blank"
              rel="noopener noreferrer"
            >
              Open document
            </a>
          ) : (
            <p className="document-note">{summary?.text}</p>
          )}
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!importFile}
        onOpenChange={(open) => {
          if (!open && !working) setImportFile(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>Import inventory</DialogTitle>
          <DialogDescription>{importFile?.name}</DialogDescription>
          <label htmlFor="import-space">Destination Space</label>
          <select
            id="import-space"
            className="workspace-input"
            value={importSpace}
            onChange={(e) => setImportSpace(e.target.value)}
          >
            <option value="">Choose a Space</option>
            {spaces.map((s) => (
              <option key={s.id} value={s.name}>
                {s.name}
              </option>
            ))}
            <option value="Unsorted">Unsorted</option>
          </select>
          {error && <p role="alert">{error}</p>}
          <div className="workspace-actions">
            <Link className="workspace-button" href="/scan">
              Capture and create a Space
            </Link>
            <button
              className="workspace-button primary"
              disabled={working || !importSpace}
              onClick={() =>
                void perform(async (account) => {
                  if (!importFile) return;
                  const form = new FormData();
                  form.append("file", importFile);
                  form.append("location", importSpace);
                  const result = await accountRequest<{
                    inserted: number;
                    failures: number;
                  }>(account, "/import/spreadsheet", {
                    method: "POST",
                    body: form,
                  });
                  if (owner.current === account) {
                    setImportFile(null);
                    setMessage(
                      `Import complete: ${result.inserted} items added, ${result.failures} failed.`,
                    );
                  }
                })
              }
            >
              Import
            </button>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}
