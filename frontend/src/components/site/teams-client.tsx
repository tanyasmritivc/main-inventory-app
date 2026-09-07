"use client";

import { ChangeEvent, FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Archive, Clipboard, FileText, History, Link2, MoreHorizontal, Plus,
  RefreshCw, Send, Trash2, UserMinus, Users,
} from "lucide-react";
import {
  ActivityEntry, InventoryItem, Space, TeamBoardTask, TeamData, TeamDocument, TeamMember, TeamRole, TeamSpace,
  addTeamSpaceItem, attachTeamSpace, createTeam, createTeamBoardTask, createTeamSpace,
  deleteTeam, deleteTeamBoardTask, deleteTeamDocument, deleteTeamSpaceItem, detachTeamSpace,
  emailTeamInvite, getMyTeams, getSpaces, getTeamActivity, getTeamBoard, getTeamDocuments,
  getTeamInvite, getTeamMembers, getTeamSpaceItems, getTeamSpaces, getTeamWorkspace,
  joinTeam, leaveTeam, openTeamDocument, removeTeamMember, rotateTeamJoinCode,
  updateTeamBoardTask, updateTeamMemberRole, updateTeamSpaceItem, uploadTeamDocument,
} from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

type Tab = "spaces" | "board" | "people" | "files" | "activity";
type CreateMode = "team" | "join" | "space" | "attach" | "task" | "item";

function relativeTime(value?: string) {
  if (!value) return "";
  const minutes = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 60000));
  if (minutes < 1) return "just now"; if (minutes < 60) return `${minutes}m ago`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h ago`; return `${Math.floor(minutes / 1440)}d ago`;
}

function memberName(member?: TeamMember) { return member?.display_name?.trim() || member?.contact_email?.trim() || "Team member"; }

export function TeamsClient() {
  const { token } = useApiSession();
  const [teams, setTeams] = useState<TeamData[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [team, setTeam] = useState<(TeamData & { owner_user_id?: string }) | null>(null);
  const [role, setRole] = useState<TeamRole>("viewer");
  const [tab, setTab] = useState<Tab>("spaces");
  const [spaces, setSpaces] = useState<TeamSpace[]>([]);
  const [board, setBoard] = useState<TeamBoardTask[]>([]);
  const [members, setMembers] = useState<TeamMember[]>([]);
  const [documents, setDocuments] = useState<TeamDocument[]>([]);
  const [activity, setActivity] = useState<ActivityEntry[]>([]);
  const [ownedSpaces, setOwnedSpaces] = useState<Space[]>([]);
  const [openSpace, setOpenSpace] = useState<TeamSpace | null>(null);
  const [spaceItems, setSpaceItems] = useState<InventoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [createMode, setCreateMode] = useState<CreateMode | null>(null);
  const [form, setForm] = useState<Record<string, string>>({ program: "robotics", task_type: "task", priority: "normal", quantity: "1", category: "Unsorted" });
  const teamFileRef = useRef<HTMLInputElement>(null);

  const canEdit = role !== "viewer";
  const canManage = role === "owner" || role === "mentor";
  const selectedTeam = teams.find((entry) => entry.team_id === selectedId);

  const loadTeams = useCallback(async () => {
    if (!token) return;
    setLoading(true); setError(null);
    try {
      const result = await getMyTeams({ token });
      setTeams(result.teams ?? []);
      setSelectedId((current) => current && result.teams.some((entry) => entry.team_id === current) ? current : result.teams[0]?.team_id ?? null);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Could not load teams."); }
    finally { setLoading(false); }
  }, [token]);

  const loadWorkspace = useCallback(async () => {
    if (!token || !selectedId) return;
    setLoading(true); setError(null);
    try {
      const [workspace, teamSpaces, teamBoard, teamMembers, teamDocs, teamActivity, personalSpaces] = await Promise.all([
        getTeamWorkspace({ token, teamId: selectedId }), getTeamSpaces({ token, teamId: selectedId }),
        getTeamBoard({ token, teamId: selectedId }), getTeamMembers({ token, teamId: selectedId }),
        getTeamDocuments({ token, teamId: selectedId }), getTeamActivity({ token, teamId: selectedId }), getSpaces({ token }),
      ]);
      setTeam(workspace.team); setRole(workspace.role); setSpaces(teamSpaces.spaces ?? []); setBoard(teamBoard.tasks ?? []);
      setMembers(teamMembers); setDocuments(teamDocs.documents ?? []); setActivity(teamActivity.activity ?? []); setOwnedSpaces(personalSpaces);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Could not load this team workspace."); }
    finally { setLoading(false); }
  }, [selectedId, token]);

  useEffect(() => { void loadTeams(); }, [loadTeams]);
  useEffect(() => { void loadWorkspace(); }, [loadWorkspace]);
  useEffect(() => { const timer = window.setInterval(() => { if (!document.hidden) void loadWorkspace(); }, 20_000); return () => window.clearInterval(timer); }, [loadWorkspace]);

  async function submitCreate(event: FormEvent) {
    event.preventDefault(); if (!token || !createMode) return;
    setWorking(true); setError(null);
    try {
      if (createMode === "team") await createTeam({ token, name: form.name?.trim() ?? "", program: (form.program || "robotics") as Parameters<typeof createTeam>[0]["program"] });
      if (createMode === "join") await joinTeam({ token, code: form.code ?? "" });
      if (createMode === "space" && selectedId) await createTeamSpace({ token, teamId: selectedId, name: form.name?.trim() ?? "" });
      if (createMode === "attach" && selectedId) await attachTeamSpace({ token, teamId: selectedId, spaceId: form.space_id });
      if (createMode === "task" && selectedId) await createTeamBoardTask({ token, teamId: selectedId, task: { title: form.title?.trim() ?? "", description: form.description ?? "", task_type: (form.task_type || "task") as TeamBoardTask["task_type"], priority: (form.priority || "normal") as TeamBoardTask["priority"], assigned_to: form.assigned_to || null, due_at: form.due_at || null } });
      if (createMode === "item" && selectedId && openSpace) await addTeamSpaceItem({ token, teamId: selectedId, spaceId: openSpace.id, item: { name: form.name?.trim() ?? "", category: form.category || "Unsorted", quantity: Number(form.quantity || 1), location: openSpace.name } });
      setCreateMode(null); setForm({ program: "robotics", task_type: "task", priority: "normal", quantity: "1", category: "Unsorted" });
      await loadTeams(); await loadWorkspace(); if (openSpace) await loadSpace(openSpace);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "That team change could not be saved."); }
    finally { setWorking(false); }
  }

  async function loadSpace(space: TeamSpace) {
    if (!token || !selectedId) return;
    setOpenSpace(space); setWorking(true);
    try { const result = await getTeamSpaceItems({ token, teamId: selectedId, spaceId: space.id }); setSpaceItems(result.items ?? []); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Could not load this Team Space."); }
    finally { setWorking(false); }
  }

  async function changeTask(task: TeamBoardTask, updates: Partial<TeamBoardTask>) {
    if (!token || !selectedId) return; setWorking(true);
    try { await updateTeamBoardTask({ token, teamId: selectedId, taskId: task.task_id, updates }); await loadWorkspace(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Could not update that board item."); }
    finally { setWorking(false); }
  }

  async function removeTask(task: TeamBoardTask) {
    if (!token || !selectedId || !window.confirm(`Delete “${task.title}”?`)) return;
    await deleteTeamBoardTask({ token, teamId: selectedId, taskId: task.task_id }); await loadWorkspace();
  }

  async function removeSpace(space: TeamSpace) {
    if (!token || !selectedId || !window.confirm(`Remove “${space.name}” from this team? Its inventory will not be deleted.`)) return;
    await detachTeamSpace({ token, teamId: selectedId, spaceId: space.id }); if (openSpace?.id === space.id) setOpenSpace(null); await loadWorkspace();
  }

  async function editSpaceItem(item: InventoryItem) {
    if (!token || !selectedId || !openSpace) return;
    const quantity = window.prompt(`Quantity for ${item.name}`, String(item.quantity)); if (quantity === null) return;
    await updateTeamSpaceItem({ token, teamId: selectedId, spaceId: openSpace.id, itemId: item.item_id, updates: { quantity: Number(quantity) } }); await loadSpace(openSpace);
  }

  async function removeSpaceItem(item: InventoryItem) {
    if (!token || !selectedId || !openSpace || !window.confirm(`Delete “${item.name}”?`)) return;
    await deleteTeamSpaceItem({ token, teamId: selectedId, spaceId: openSpace.id, itemId: item.item_id }); await loadSpace(openSpace);
  }

  async function updateRole(member: TeamMember, nextRole: TeamRole) {
    if (!token || !selectedId) return;
    await updateTeamMemberRole({ token, teamId: selectedId, userId: member.user_id, role: nextRole }); await loadWorkspace();
  }

  async function removeMember(member: TeamMember) {
    if (!token || !selectedId || !window.confirm(`Remove ${memberName(member)} from this team?`)) return;
    await removeTeamMember({ token, teamId: selectedId, userId: member.user_id }); await loadWorkspace();
  }

  async function copyInvite() {
    if (!token || !selectedId) return; const invite = await getTeamInvite({ token, teamId: selectedId }); await navigator.clipboard.writeText(invite.invite_url);
  }

  async function sendInvite() {
    if (!token || !selectedId) return; const email = window.prompt("Email address to invite"); if (!email) return;
    await emailTeamInvite({ token, teamId: selectedId, email });
  }

  async function rotateCode() {
    if (!token || !selectedId || !window.confirm("Reset the join code? The old code will stop working.")) return;
    await rotateTeamJoinCode({ token, teamId: selectedId }); await loadWorkspace();
  }

  async function uploadDocument(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; if (!token || !selectedId || !file) return;
    setWorking(true); try { await uploadTeamDocument({ token, teamId: selectedId, file }); await loadWorkspace(); } finally { setWorking(false); event.target.value = ""; }
  }

  async function openDocument(document: TeamDocument) {
    if (!token || !selectedId) return; const result = await openTeamDocument({ token, teamId: selectedId, documentId: document.team_document_id }); window.open(result.url, "_blank", "noopener,noreferrer");
  }

  async function removeDocument(document: TeamDocument) {
    if (!token || !selectedId || !window.confirm(`Delete “${document.filename}”?`)) return;
    await deleteTeamDocument({ token, teamId: selectedId, documentId: document.team_document_id }); await loadWorkspace();
  }

  async function exitTeam() {
    if (!token || !selectedId || !team) return;
    const deleting = role === "owner"; if (!window.confirm(`${deleting ? "Delete" : "Leave"} “${team.name}”?`)) return;
    if (deleting) await deleteTeam({ token, teamId: selectedId }); else await leaveTeam({ token, teamId: selectedId });
    setSelectedId(null); setTeam(null); await loadTeams();
  }

  const availableSpaces = ownedSpaces.filter((space) => !spaces.some((teamSpace) => teamSpace.id === space.id));
  const memberMap = useMemo(() => new Map(members.map((member) => [member.user_id, member])), [members]);

  if (!selectedId && !loading) return <section className="product-page"><header className="product-page-header"><div><h1>Teams</h1><p>Shared Spaces, work, people, files, and activity in one place.</p></div><div className="product-actions"><button className="product-button" onClick={() => setCreateMode("join")}>Join team</button><button className="product-button primary" onClick={() => setCreateMode("team")}><Plus size={15} />Create team</button></div></header>{createMode && <TeamCreateForm mode={createMode} form={form} setForm={setForm} onSubmit={submitCreate} onCancel={() => setCreateMode(null)} working={working} />}{error && <div className="notice-error">{error}</div>}<div className="product-card product-empty"><div><Users size={28} /><strong>No teams yet</strong><span>Create one or join with an invitation code.</span></div></div></section>;

  return (
    <section className="teams-page product-page">
      <header className="product-page-header"><div><h1>{team?.name || selectedTeam?.name || "Teams"}</h1><p>{team?.program || selectedTeam?.program || "Team workspace"} · {role}</p></div><div className="product-actions"><button className="product-button" onClick={() => setCreateMode("join")}>Join another</button><button className="product-button" onClick={() => setCreateMode("team")}><Plus size={15} />New team</button><button className="product-button" onClick={() => void loadWorkspace()}><RefreshCw size={15} /></button></div></header>
      <div className="team-switcher product-card"><label>Current team<select className="product-select" value={selectedId ?? ""} onChange={(event) => { setSelectedId(event.target.value); setOpenSpace(null); }}>{teams.map((entry) => <option key={entry.team_id} value={entry.team_id}>{entry.name}</option>)}</select></label><span className="status-pill">{role}</span></div>
      {createMode && <TeamCreateForm mode={createMode} form={form} setForm={setForm} onSubmit={submitCreate} onCancel={() => setCreateMode(null)} working={working} spaces={availableSpaces} members={members} />}
      {error && <div className="notice-error">{error}</div>}
      <div className="product-tabs">{(["spaces", "board", "people", "files", "activity"] as Tab[]).map((value) => <button className={tab === value ? "is-active" : ""} key={value} onClick={() => setTab(value)}>{value[0].toUpperCase() + value.slice(1)}{value === "spaces" ? ` ${spaces.length}` : value === "board" ? ` ${board.filter((task) => task.status !== "done").length}` : ""}</button>)}</div>

      {tab === "spaces" && <div className="team-panel"><div className="team-panel-heading"><div><h2>Team Spaces</h2><p>Everyone on this team sees the same linked inventory.</p></div>{canEdit && <div className="product-actions">{canManage && <button className="product-button" onClick={() => setCreateMode("space")}><Plus size={14} />Create</button>}<button className="product-button primary" onClick={() => setCreateMode("attach")}><Link2 size={14} />Add existing</button></div>}</div>{openSpace ? <div className="team-space-detail product-card"><div className="team-space-detail-head"><button className="product-button" onClick={() => setOpenSpace(null)}>← All Spaces</button><div><h3>{openSpace.name}</h3><span>{spaceItems.length} items</span></div>{canEdit && <button className="product-button primary" onClick={() => setCreateMode("item")}><Plus size={14} />Add item</button>}</div><div className="team-item-table"><div className="team-item-head"><span>Item</span><span>Category</span><span>Quantity</span><span /></div>{spaceItems.map((item) => <div className="team-item-row" key={item.item_id}><span><strong>{item.name}</strong><small>{item.part_number || item.brand || ""}</small></span><span>{item.category}</span><span>{item.quantity}</span><span>{canEdit && <><button onClick={() => void editSpaceItem(item)}>Edit qty</button><button onClick={() => void removeSpaceItem(item)}>Delete</button></>}</span></div>)}</div></div> : <div className="team-space-grid">{spaces.map((space) => <article className="product-card" key={space.id}><button onClick={() => void loadSpace(space)}><Archive size={20} /><span><strong>{space.name}</strong><small>{space.item_count ?? 0} items{space.owned_by_me ? " · You own this" : ""}</small></span></button>{(canManage || space.owned_by_me) && <button className="team-card-menu" onClick={() => void removeSpace(space)} aria-label={`Remove ${space.name}`}><Trash2 size={14} /></button>}</article>)}{spaces.length === 0 && <div className="product-card product-empty"><div><Archive size={26} /><strong>No Team Spaces</strong><span>Create one or add an existing Space.</span></div></div>}</div>}</div>}

      {tab === "board" && <div className="team-panel"><div className="team-panel-heading"><div><h2>Team Board</h2><p>Tasks, checklists, and part requests.</p></div>{canEdit && <button className="product-button primary" onClick={() => setCreateMode("task")}><Plus size={14} />New board item</button>}</div><div className="board-columns">{(["todo", "doing", "done"] as const).map((status) => <section key={status}><header><span>{status === "todo" ? "To do" : status === "doing" ? "In progress" : "Done"}</span><small>{board.filter((task) => task.status === status).length}</small></header><div>{board.filter((task) => task.status === status).map((task) => <article className="board-card product-card" key={task.task_id}><div className="board-card-top"><span className={`status-pill ${task.priority === "urgent" ? "red" : task.priority === "high" ? "amber" : ""}`}>{task.task_type.replace("_", " ")}</span>{canEdit && <button onClick={() => void removeTask(task)}><MoreHorizontal size={15} /></button>}</div><h3>{task.title}</h3>{task.description && <p>{task.description}</p>}<footer><span>{task.assigned_to ? memberName(memberMap.get(task.assigned_to)) : "Unassigned"}</span>{canEdit && <select value={task.status} onChange={(event) => void changeTask(task, { status: event.target.value as TeamBoardTask["status"] })}><option value="todo">To do</option><option value="doing">In progress</option><option value="done">Done</option></select>}</footer></article>)}</div></section>)}</div></div>}

      {tab === "people" && <div className="team-panel"><div className="team-panel-heading"><div><h2>People</h2><p>Roles control who can view, edit, and manage the workspace.</p></div>{canManage && <div className="product-actions"><button className="product-button" onClick={() => void copyInvite()}><Clipboard size={14} />Copy invite</button><button className="product-button primary" onClick={() => void sendInvite()}><Send size={14} />Email invite</button></div>}</div>{canManage && team?.join_code && <div className="invite-code product-card"><span>Join code</span><strong>{team.join_code}</strong><button className="product-button" onClick={() => void rotateCode()}>Reset code</button></div>}<div className="people-list product-card">{members.map((member) => <article key={member.user_id}><div className="member-avatar" style={{ background: member.avatar_color || "#3a3a3c" }}>{memberName(member)[0]?.toUpperCase()}</div><div><strong>{memberName(member)}</strong><span>{[member.profile_role, member.organization, member.contact_email].filter(Boolean).join(" · ")}</span></div>{canManage && member.role !== "owner" ? <select value={member.role} onChange={(event) => void updateRole(member, event.target.value as TeamRole)}><option value="mentor">Manager</option><option value="member">Member</option><option value="viewer">Viewer</option></select> : <span className="status-pill">{member.role}</span>}{canManage && member.role !== "owner" && <button className="app-icon-button" onClick={() => void removeMember(member)} aria-label={`Remove ${memberName(member)}`}><UserMinus size={15} /></button>}</article>)}</div><button className="product-button danger team-exit" onClick={() => void exitTeam()}>{role === "owner" ? "Delete team" : "Leave team"}</button></div>}

      {tab === "files" && <div className="team-panel"><div className="team-panel-heading"><div><h2>Team files</h2><p>Shared references, drawings, BOMs, and build documentation.</p></div>{canEdit && <><button className="product-button primary" onClick={() => teamFileRef.current?.click()}><Plus size={14} />Upload file</button><input ref={teamFileRef} hidden type="file" onChange={(event) => void uploadDocument(event)} /></>}</div><div className="team-files product-card">{documents.map((document) => <article key={document.team_document_id}><FileText size={18} /><button onClick={() => void openDocument(document)}><strong>{document.filename}</strong><span>{relativeTime(document.created_at)} · {document.size_bytes ? `${Math.ceil(document.size_bytes / 1024)} KB` : "File"}</span></button>{canEdit && <button className="app-icon-button" onClick={() => void removeDocument(document)}><Trash2 size={14} /></button>}</article>)}{documents.length === 0 && <div className="product-empty"><div><FileText size={26} /><strong>No team files</strong><span>Upload a reference everyone can access.</span></div></div>}</div></div>}

      {tab === "activity" && <div className="team-panel"><div className="team-panel-heading"><div><h2>Team activity</h2><p>A durable audit trail of changes across this workspace.</p></div></div><div className="product-card activity-feed">{activity.map((entry) => <article className="activity-row" key={entry.activity_id}><span className="activity-icon"><History size={15} /></span><div><div className="activity-copy">{entry.summary}</div><div className="activity-meta">{relativeTime(entry.created_at)}</div></div></article>)}{activity.length === 0 && <div className="product-empty"><div><History size={26} /><strong>No activity yet</strong><span>Team changes will be recorded here.</span></div></div>}</div></div>}
    </section>
  );
}

function TeamCreateForm({ mode, form, setForm, onSubmit, onCancel, working, spaces = [], members = [] }: { mode: CreateMode; form: Record<string, string>; setForm: React.Dispatch<React.SetStateAction<Record<string, string>>>; onSubmit: (event: FormEvent) => void; onCancel: () => void; working: boolean; spaces?: Space[]; members?: TeamMember[] }) {
  const set = (key: string, value: string) => setForm((current) => ({ ...current, [key]: value }));
  const titles = { team: "Create team", join: "Join a team", space: "Create Team Space", attach: "Add existing Space", task: "New board item", item: "Add inventory item" };
  return <form className="team-create product-card" onSubmit={onSubmit}><div><h2>{titles[mode]}</h2><p>{mode === "attach" ? "Linking keeps ownership intact and makes the Space visible to every team member." : mode === "join" ? "Enter the invitation code shared by a team manager." : "Complete the details below."}</p></div>{mode === "join" && <input required className="product-input" value={form.code ?? ""} onChange={(event) => set("code", event.target.value.toUpperCase())} placeholder="JOIN CODE" />}{(mode === "team" || mode === "space" || mode === "item") && <input required className="product-input" value={form.name ?? ""} onChange={(event) => set("name", event.target.value)} placeholder={mode === "team" ? "Team name" : mode === "space" ? "Space name" : "Item name"} />}{mode === "team" && <select className="product-select" value={form.program || "robotics"} onChange={(event) => set("program", event.target.value)}><option value="robotics">Robotics</option><option value="ftc">FTC</option><option value="frc">FRC</option><option value="fll">FLL</option><option value="vex">VEX</option><option value="education">School</option><option value="makerspace">Makerspace</option><option value="club">Club</option><option value="business">Business</option><option value="other">Other</option></select>}{mode === "attach" && <select required className="product-select" value={form.space_id ?? ""} onChange={(event) => set("space_id", event.target.value)}><option value="">Choose a Space…</option>{spaces.map((space) => <option key={space.id} value={space.id}>{space.name}</option>)}</select>}{mode === "task" && <><input required className="product-input" value={form.title ?? ""} onChange={(event) => set("title", event.target.value)} placeholder="Title" /><textarea className="product-textarea" value={form.description ?? ""} onChange={(event) => set("description", event.target.value)} placeholder="Description" /><div className="team-form-grid"><select className="product-select" value={form.task_type || "task"} onChange={(event) => set("task_type", event.target.value)}><option value="task">Task</option><option value="checklist">Checklist</option><option value="part_request">Part request</option></select><select className="product-select" value={form.priority || "normal"} onChange={(event) => set("priority", event.target.value)}><option value="normal">Normal</option><option value="high">High</option><option value="urgent">Urgent</option></select><select className="product-select" value={form.assigned_to ?? ""} onChange={(event) => set("assigned_to", event.target.value)}><option value="">Unassigned</option>{members.map((member) => <option key={member.user_id} value={member.user_id}>{memberName(member)}</option>)}</select><input className="product-input" type="datetime-local" value={form.due_at ?? ""} onChange={(event) => set("due_at", event.target.value)} /></div></>}{mode === "item" && <div className="team-form-grid"><input required className="product-input" value={form.category || "Unsorted"} onChange={(event) => set("category", event.target.value)} placeholder="Category" /><input required className="product-input" type="number" min="0" value={form.quantity || "1"} onChange={(event) => set("quantity", event.target.value)} /></div>}<div className="product-actions"><button type="button" className="product-button" onClick={onCancel}>Cancel</button><button className="product-button primary" disabled={working}>{working ? "Saving…" : "Save"}</button></div></form>;
}
