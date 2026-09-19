"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { BookOpen, Camera, ChevronRight, KeyRound, LogOut, Trash2 } from "lucide-react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { deleteProfilePhoto, getMyProfile, updateProfile, uploadProfilePhoto } from "@/lib/api";
import { useAppDialog } from "@/components/site/app-dialog-provider";

const AVATAR_COLORS = ["#3A1230", "#6B1C3C", "#8E2F3A", "#A93454", "#B2452F", "#AC4A61", "#8D4A61", "#7A3B50"];

type Profile = {
  display_name: string;
  contact_email: string;
  avatar_color: string;
  avatar_url?: string;
  organization?: string;
  profile_role?: string;
};

export function SettingsClient({ email }: { email: string | null }) {
  const { promptValue, showNotice } = useAppDialog();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const router = useRouter();
  const photoRef = useRef<HTMLInputElement>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [editingName, setEditingName] = useState("");
  const [editingEmail, setEditingEmail] = useState("");
  const [editingOrganization, setEditingOrganization] = useState("");
  const [editingRole, setEditingRole] = useState("");
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileMessage, setProfileMessage] = useState<string | null>(null);
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) return;
      getMyProfile({ token }).then((nextProfile) => {
        setProfile(nextProfile);
        setEditingName(nextProfile.display_name ?? "");
        setEditingEmail(nextProfile.contact_email ?? "");
        setEditingOrganization(nextProfile.organization ?? "");
        setEditingRole(nextProfile.profile_role ?? "");
      }).catch(() => setProfileMessage("Profile details could not be loaded."));
    }).catch(() => setProfileMessage("Profile details could not be loaded."));
  }, [supabase]);

  async function saveProfile() {
    setSavingProfile(true);
    setProfileMessage(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error("No active session");
      await updateProfile({
        token: session.access_token,
        displayName: editingName,
        contactEmail: editingEmail,
        organization: editingOrganization,
        profileRole: editingRole,
      });
      setProfileMessage("Profile saved.");
    } catch {
      setProfileMessage("Your profile could not be saved.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function changePhoto(file?: File) {
    if (!file) return;
    setSavingProfile(true);
    setProfileMessage(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error("No active session");
      const result = await uploadProfilePhoto({ token: session.access_token, file });
      setProfile((current) => current ? { ...current, avatar_url: result.avatar_url } : current);
      setProfileMessage("Profile photo updated.");
    } catch {
      setProfileMessage("The photo could not be updated.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function removePhoto() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;
    try {
      await deleteProfilePhoto({ token: session.access_token });
      setProfile((current) => current ? { ...current, avatar_url: undefined } : current);
      setProfileMessage("Profile photo removed.");
    } catch {
      setProfileMessage("The photo could not be removed.");
    }
  }

  async function changeAvatarColor(color: string) {
    setProfile((current) => current ? { ...current, avatar_color: color } : current);
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;
    try {
      await updateProfile({ token: session.access_token, avatarColor: color });
    } catch {
      setProfileMessage("The avatar color could not be saved.");
    }
  }

  async function onSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      await supabase.auth.signOut();
      router.replace("/");
      router.refresh();
    } finally {
      setSigningOut(false);
    }
  }

  async function deleteAccount() {
    const confirmation = await promptValue({
      title: "Delete account?",
      message: "This permanently deletes your FindEZ account and associated data. This cannot be undone.",
      label: "Confirmation",
      placeholder: "DELETE",
      requiredValue: "DELETE",
      confirmLabel: "Delete account",
      danger: true,
    });
    if (confirmation !== "DELETE") return;
    const { error } = await supabase.functions.invoke("delete-user");
    if (error) {
      await showNotice({ title: "Account not deleted", message: "Your account could not be deleted. No data was removed." });
      return;
    }
    await supabase.auth.signOut();
    router.replace("/");
    router.refresh();
  }

  return (
    <div className="settings-content">
      <section className="settings-panel">
        <header><h2>Profile</h2></header>
        <div className="settings-profile-row">
          <button className="settings-avatar" type="button" onClick={() => photoRef.current?.click()} aria-label="Change profile photo" style={{ backgroundColor: profile?.avatar_color ?? "#3A1230", backgroundImage: profile?.avatar_url ? `url(${profile.avatar_url})` : undefined }}>
            {!profile?.avatar_url && (editingName || email || "?")[0].toUpperCase()}
            <span><Camera size={12} /></span>
          </button>
          <input ref={photoRef} hidden type="file" accept="image/jpeg,image/png,image/webp" onChange={(event) => void changePhoto(event.target.files?.[0])} />
          <div><strong>Profile image</strong></div>
          <div className="settings-row-actions"><button className="product-button" type="button" onClick={() => photoRef.current?.click()}>Change</button>{profile?.avatar_url && <button className="settings-text-button" type="button" onClick={() => void removePhoto()}>Remove</button>}</div>
        </div>
        <div className="settings-form-row"><label htmlFor="settings-name">Display name</label><div><input id="settings-name" value={editingName} onChange={(event) => setEditingName(event.target.value)} placeholder="Your name" /></div></div>
        <div className="settings-form-row"><label htmlFor="settings-role">Role</label><div><input id="settings-role" value={editingRole} onChange={(event) => setEditingRole(event.target.value)} placeholder="Build lead" /></div></div>
        <div className="settings-form-row"><label htmlFor="settings-organization">Organization</label><div><input id="settings-organization" value={editingOrganization} onChange={(event) => setEditingOrganization(event.target.value)} placeholder="Team or organization" /></div></div>
        <div className="settings-form-row"><label htmlFor="settings-contact-email">Contact email</label><div><input id="settings-contact-email" type="email" value={editingEmail} onChange={(event) => setEditingEmail(event.target.value)} placeholder="name@example.com" /></div></div>
        <div className="settings-form-row settings-color-row"><span>Avatar color</span><div>{AVATAR_COLORS.map((color) => <button key={color} type="button" aria-label={`Use avatar color ${color}`} aria-pressed={profile?.avatar_color === color} onClick={() => void changeAvatarColor(color)} style={{ background: color }} />)}</div></div>
        <footer><span role="status">{profileMessage}</span><button className="product-button primary" type="button" onClick={() => void saveProfile()} disabled={savingProfile}>{savingProfile ? "Saving…" : "Save changes"}</button></footer>
      </section>

      <section className="settings-panel">
        <header><h2>Developer</h2></header>
        <Link className="settings-link-row" href="/settings/api-keys"><span className="settings-row-icon"><KeyRound size={16} /></span><span><strong>API keys</strong></span><ChevronRight size={16} /></Link>
        <Link className="settings-link-row" href="/docs/api"><span className="settings-row-icon"><BookOpen size={16} /></span><span><strong>API documentation</strong></span><ChevronRight size={16} /></Link>
      </section>

      <section className="settings-panel">
        <header><h2>Account</h2></header>
        <div className="settings-static-row"><span>Email</span><strong>{email || "—"}</strong></div>
        <div className="settings-static-row"><span><LogOut size={15} />Session</span><button className="settings-text-button" type="button" onClick={() => void onSignOut()} disabled={signingOut}>{signingOut ? "Signing out…" : "Sign out"}</button></div>
        <div className="settings-static-row settings-danger-row"><span><Trash2 size={15} />Delete account<small>Permanently removes your account and associated data.</small></span><button className="settings-text-button danger" type="button" onClick={() => void deleteAccount()}>Delete…</button></div>
      </section>
    </div>
  );
}
