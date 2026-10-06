"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  BookOpen,
  Camera,
  ChevronRight,
  KeyRound,
  LogOut,
  Trash2,
} from "lucide-react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import {
  useAppTheme,
  type AppThemeChoice,
} from "@/components/site/use-app-theme";

const THEME_CHOICES: { value: AppThemeChoice; label: string }[] = [
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
  { value: "system", label: "System" },
];

const AVATAR_COLORS = [
  "#3A1230",
  "#6B1C3C",
  "#8E2F3A",
  "#A93454",
  "#B2452F",
  "#AC4A61",
  "#8D4A61",
  "#7A3B50",
];

type Profile = {
  display_name: string;
  contact_email: string;
  avatar_color: string;
  avatar_url?: string;
  organization?: string;
  profile_role?: string;
};

export function SettingsClient({ email }: { email: string | null }) {
  const { accountId } = useApiSession();
  return <SettingsWorkspace key={accountId || "signed-out"} email={email} />;
}
function SettingsWorkspace({ email }: { email: string | null }) {
  const { accountId } = useApiSession();
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const { promptValue, showNotice } = useAppDialog();
  const { theme, setTheme } = useAppTheme();
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
    if (!accountId) return;
    let active = true;
    const account = accountId;
    accountRequest<Profile>(account, "/profile/me")
      .then((next) => {
        if (!active) return;
        setProfile(next);
        setEditingName(next.display_name || "");
        setEditingEmail(next.contact_email || "");
        setEditingOrganization(next.organization || "");
        setEditingRole(next.profile_role || "");
      })
      .catch(() => {
        if (active)
          setProfileMessage(
            "Profile details could not be loaded. Reload to try again.",
          );
      });
    return () => {
      active = false;
    };
  }, [accountId]);

  async function saveProfile() {
    setSavingProfile(true);
    setProfileMessage(null);
    try {
      if (!accountId) throw new Error("Please sign in again.");
      const next = await accountRequest<{ updated: boolean }>(
        accountId,
        "/profile/update",
        {
          method: "PATCH",
          body: {
            display_name: editingName,
            contact_email: editingEmail,
            organization: editingOrganization,
            profile_role: editingRole,
          },
        },
      );
      if (owner.current !== accountId) return;
      if (!next.updated)
        throw new Error("Your profile update was not confirmed.");
      setProfile((current) =>
        current
          ? {
              ...current,
              display_name: editingName,
              contact_email: editingEmail,
              organization: editingOrganization,
              profile_role: editingRole,
            }
          : current,
      );
      window.dispatchEvent(new Event("findez-profile-changed"));
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
      if (!accountId) throw new Error("Please sign in again.");
      const form = new FormData();
      form.append("file", file);
      const result = await accountRequest<{ avatar_url: string }>(
        accountId,
        "/profile/photo",
        { method: "POST", body: form },
      );
      if (owner.current !== accountId) return;
      window.dispatchEvent(new Event("findez-profile-changed"));
      setProfile((current) =>
        current ? { ...current, avatar_url: result.avatar_url } : current,
      );
      setProfileMessage("Profile photo updated.");
    } catch {
      setProfileMessage("The photo could not be updated.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function removePhoto() {
    if (!accountId || savingProfile) return;
    setSavingProfile(true);
    try {
      await accountRequest(accountId, "/profile/photo", { method: "DELETE" });
      if (owner.current !== accountId) return;
      window.dispatchEvent(new Event("findez-profile-changed"));
      setProfile((current) =>
        current ? { ...current, avatar_url: undefined } : current,
      );
      setProfileMessage("Profile photo removed.");
    } catch {
      setProfileMessage("The photo could not be removed.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function changeAvatarColor(color: string) {
    if (!accountId || savingProfile) return;
    setSavingProfile(true);
    setProfileMessage(null);
    try {
      const result = await accountRequest<{ updated: boolean }>(
        accountId,
        "/profile/update",
        { method: "PATCH", body: { avatar_color: color } },
      );
      if (!result.updated)
        throw new Error("The avatar update was not confirmed.");
      if (owner.current === accountId) {
        setProfile((current) =>
          current ? { ...current, avatar_color: color } : current,
        );
        window.dispatchEvent(new Event("findez-profile-changed"));
      }
    } catch {
      setProfileMessage("The avatar color could not be saved.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function onSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      const { error } = await supabase.auth.signOut();
      if (error) {
        setProfileMessage("Could not sign out. Please try again.");
        return;
      }
      router.replace("/");
      router.refresh();
    } finally {
      setSigningOut(false);
    }
  }

  async function deleteAccount() {
    const confirmation = await promptValue({
      title: "Delete account?",
      message:
        "This permanently deletes your FindEZ account and associated data. This cannot be undone.",
      label: "Confirmation",
      placeholder: "DELETE",
      requiredValue: "DELETE",
      confirmLabel: "Delete account",
      danger: true,
    });
    if (confirmation !== "DELETE") return;
    const { error } = await supabase.functions.invoke("delete-user");
    if (error) {
      await showNotice({
        title: "Account not deleted",
        message: "Your account could not be deleted. No data was removed.",
      });
      return;
    }
    await supabase.auth.signOut();
    router.replace("/");
    router.refresh();
  }

  return (
    <div className="settings-content">
      <section className="settings-panel">
        <header>
          <h2>Profile</h2>
        </header>
        <div className="settings-profile-row">
          <button
            className="settings-avatar"
            type="button"
            onClick={() => photoRef.current?.click()}
            aria-label="Change profile photo"
            style={{
              backgroundColor: profile?.avatar_color ?? "#3A1230",
              backgroundImage: profile?.avatar_url
                ? `url(${profile.avatar_url})`
                : undefined,
            }}
          >
            {!profile?.avatar_url &&
              (editingName || email || "?")[0].toUpperCase()}
            <span>
              <Camera size={12} />
            </span>
          </button>
          <input
            ref={photoRef}
            hidden
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={(event) => void changePhoto(event.target.files?.[0])}
          />
          <div>
            <strong>Profile image</strong>
          </div>
          <div className="settings-row-actions">
            <button
              className="product-button"
              type="button"
              onClick={() => photoRef.current?.click()}
            >
              Change
            </button>
            {profile?.avatar_url && (
              <button
                className="settings-text-button"
                type="button"
                onClick={() => void removePhoto()}
              >
                Remove
              </button>
            )}
          </div>
        </div>
        <div className="settings-form-row">
          <label htmlFor="settings-name">Display name</label>
          <div>
            <input
              id="settings-name"
              value={editingName}
              onChange={(event) => setEditingName(event.target.value)}
              placeholder="Your name"
            />
          </div>
        </div>
        <div className="settings-form-row">
          <label htmlFor="settings-role">Role</label>
          <div>
            <input
              id="settings-role"
              value={editingRole}
              onChange={(event) => setEditingRole(event.target.value)}
              placeholder="Build lead"
            />
          </div>
        </div>
        <div className="settings-form-row">
          <label htmlFor="settings-organization">Organization</label>
          <div>
            <input
              id="settings-organization"
              value={editingOrganization}
              onChange={(event) => setEditingOrganization(event.target.value)}
              placeholder="Team or organization"
            />
          </div>
        </div>
        <div className="settings-form-row">
          <label htmlFor="settings-contact-email">Contact email</label>
          <div>
            <input
              id="settings-contact-email"
              type="email"
              value={editingEmail}
              onChange={(event) => setEditingEmail(event.target.value)}
              placeholder="name@example.com"
            />
          </div>
        </div>
        <div className="settings-form-row settings-color-row">
          <span>Avatar color</span>
          <div>
            {AVATAR_COLORS.map((color) => (
              <button
                key={color}
                type="button"
                aria-label={`Use avatar color ${color}`}
                aria-pressed={profile?.avatar_color === color}
                onClick={() => void changeAvatarColor(color)}
                style={{ background: color }}
              />
            ))}
          </div>
        </div>
        <footer>
          <span role="status">{profileMessage}</span>
          <button
            className="product-button primary"
            type="button"
            onClick={() => void saveProfile()}
            disabled={savingProfile}
          >
            {savingProfile ? "Saving…" : "Save changes"}
          </button>
        </footer>
      </section>

      <section className="settings-panel">
        <header>
          <h2>Developer</h2>
        </header>
        <Link className="settings-link-row" href="/settings/api-keys">
          <span className="settings-row-icon">
            <KeyRound size={16} />
          </span>
          <span>
            <strong>API keys</strong>
          </span>
          <ChevronRight size={16} />
        </Link>
        <Link className="settings-link-row" href="/docs/api">
          <span className="settings-row-icon">
            <BookOpen size={16} />
          </span>
          <span>
            <strong>API documentation</strong>
          </span>
          <ChevronRight size={16} />
        </Link>
      </section>

      <section className="settings-panel">
        <header>
          <h2>Help and information</h2>
        </header>
        <Link className="settings-link-row" href="/privacy">
          Privacy policy
          <ChevronRight size={16} />
        </Link>
        <Link className="settings-link-row" href="/terms">
          Terms of service
          <ChevronRight size={16} />
        </Link>
        <a className="settings-link-row" href="mailto:info@findez.ai">
          Contact support
          <ChevronRight size={16} />
        </a>
      </section>
      <section className="settings-panel">
        <header>
          <h2>Account</h2>
        </header>
        <div className="settings-static-row">
          <span>Email</span>
          <strong>{email || "Not available"}</strong>
        </div>
        <div className="settings-static-row">
          <span>
            Appearance<small>Follows your device unless you pick one.</small>
          </span>
          <div className="settings-theme-choice">
            {THEME_CHOICES.map((choice) => (
              <button
                key={choice.value}
                type="button"
                className={choice.value === theme ? "is-active" : ""}
                onClick={() => {
                  try {
                    setTheme(choice.value);
                  } catch {
                    setProfileMessage(
                      "Appearance could not be saved in this browser. Please try again.",
                    );
                  }
                }}
              >
                {choice.label}
              </button>
            ))}
          </div>
        </div>
        <div className="settings-static-row">
          <span>
            <LogOut size={15} />
            Session
          </span>
          <button
            className="settings-text-button"
            type="button"
            onClick={() => void onSignOut()}
            disabled={signingOut}
          >
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </div>
        <div className="settings-static-row settings-danger-row">
          <span>
            <Trash2 size={15} />
            Delete account
            <small>Permanently removes your account and associated data.</small>
          </span>
          <button
            className="settings-text-button danger"
            type="button"
            onClick={() => void deleteAccount()}
          >
            Delete…
          </button>
        </div>
      </section>
    </div>
  );
}
