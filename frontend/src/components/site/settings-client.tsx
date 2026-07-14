"use client";

import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getMyProfile, updateProfile, createCheckoutSession } from "@/lib/api";

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);
  const [isPro, setIsPro] = useState<boolean | null>(null);
  const [profile, setProfile] = useState<{ display_name: string; contact_email: string; avatar_color: string } | null>(null);
  const [editingName, setEditingName] = useState('');
  const [editingEmail, setEditingEmail] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) return;
      fetch(`${apiBase()}/stripe/subscription-status`, {
        headers: { Authorization: `Bearer ${token}` },
      })
        .then((r) => (r.ok ? r.json() : null))
        .then((d: { is_pro?: boolean } | null) => {
          if (d && typeof d.is_pro === "boolean") setIsPro(d.is_pro);
        })
        .catch(() => {});
      getMyProfile({ token }).then((prof) => {
        setProfile(prof);
        setEditingName(prof.display_name ?? '');
        setEditingEmail(prof.contact_email ?? '');
      }).catch(() => {});
    }).catch(() => {});
  }, [supabase]);

  async function onSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      await supabase.auth.signOut();
      window.location.href = "/";
    } finally {
      setSigningOut(false);
    }
  }

  return (
    <div>
      {/* PROFILE */}
      <div style={{ marginBottom: 32 }}>
        <div style={{ color: 'rgba(255,255,255,0.28)', fontSize: 10, fontWeight: 500, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 12 }}>
          PROFILE
        </div>
        <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 16, overflow: 'hidden' }}>
          {/* Avatar + name */}
          <div style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{
              width: 48, height: 48, borderRadius: '50%',
              background: profile?.avatar_color ?? '#636366',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontWeight: 700, fontSize: 20, flexShrink: 0,
            }}>
              {(editingName || '?')[0].toUpperCase()}
            </div>
            <div style={{ flex: 1 }}>
              <input
                value={editingName}
                onChange={e => setEditingName(e.target.value)}
                placeholder="Display name"
                style={{ background: 'none', border: 'none', color: '#fff', fontSize: 15, fontWeight: 600, width: '100%', outline: 'none' }}
              />
              <div style={{ color: 'rgba(255,255,255,0.45)', fontSize: 12 }}>{props.email}</div>
            </div>
          </div>
          <div style={{ height: 1, background: 'rgba(255,255,255,0.06)' }} />
          {/* Contact email */}
          <div style={{ padding: '14px 20px', display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ color: 'rgba(255,255,255,0.3)', fontSize: 13 }}>✉</span>
            <input
              value={editingEmail}
              onChange={e => setEditingEmail(e.target.value)}
              placeholder="Contact email (visible to teammates)"
              type="email"
              style={{ background: 'none', border: 'none', color: '#fff', fontSize: 13, flex: 1, outline: 'none' }}
            />
          </div>
          <div style={{ height: 1, background: 'rgba(255,255,255,0.06)' }} />
          {/* Color picker */}
          <div style={{ padding: '14px 20px' }}>
            <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, marginBottom: 10 }}>Avatar color</div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {['#0A84FF','#30D158','#FF9F0A','#FF375F','#BF5AF2','#5E5CE6','#FF6B35','#636366'].map(color => (
                <div
                  key={color}
                  onClick={async () => {
                    setProfile(p => p ? { ...p, avatar_color: color } : p);
                    const { data: { session } } = await supabase.auth.getSession();
                    if (session) await updateProfile({ token: session.access_token, avatarColor: color });
                  }}
                  style={{
                    width: 26, height: 26, borderRadius: '50%', background: color, cursor: 'pointer',
                    border: profile?.avatar_color === color ? '2px solid #fff' : '2px solid transparent',
                  }}
                />
              ))}
            </div>
          </div>
          <div style={{ height: 1, background: 'rgba(255,255,255,0.06)' }} />
          {/* Save button */}
          <div style={{ padding: '14px 20px' }}>
            <button
              type="button"
              onClick={async () => {
                setSavingProfile(true);
                try {
                  const { data: { session } } = await supabase.auth.getSession();
                  if (session) await updateProfile({ token: session.access_token, displayName: editingName, contactEmail: editingEmail });
                } finally {
                  setSavingProfile(false);
                }
              }}
              style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 99, padding: '8px 20px', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}
            >
              {savingProfile ? 'Saving...' : 'Save Profile'}
            </button>
          </div>
        </div>
      </div>
      {/* ACCOUNT */}
      <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 12 }}>Account</p>
      <div style={{ background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 12, padding: "0 20px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 0", borderBottom: "1px solid #1c1c1e" }}>
          <span style={{ fontSize: 13, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Email</span>
          <span style={{ fontSize: 13, color: "#f5f5f7", fontWeight: 400, letterSpacing: "-0.008em" }}>{props.email || "—"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 0" }}>
          <span style={{ fontSize: 13, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Session</span>
          <button
            type="button"
            onClick={() => void onSignOut()}
            disabled={signingOut}
            style={{ background: "none", border: "none", color: "#ff453a", fontSize: 13, cursor: "pointer", padding: 0, opacity: signingOut ? 0.5 : 1, fontWeight: 400, letterSpacing: "-0.008em", transition: "color 150ms" }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#ff5a52"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "#ff453a"; }}
          >
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </div>
      {/* PLAN */}
      <div style={{ marginBottom: 32, marginTop: 32 }}>
        <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: 12 }}>Plan</p>
        {isPro === false && (
          <div style={{
            background: 'rgba(255,255,255,0.03)',
            border: '1px solid rgba(255,255,255,0.07)',
            borderRadius: 16,
            padding: '20px 24px',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ color: '#a78bfa' }}>⚡</span>
                  <span style={{ fontFamily: "var(--font-syne, 'Syne', sans-serif)", fontSize: 15, fontWeight: 600, color: 'white' }}>FindEZ Pro</span>
                </div>
                <div style={{ fontFamily: "var(--font-dm-sans, sans-serif)", fontSize: 12, color: 'rgba(255,255,255,0.35)', marginTop: 3 }}>
                  $6.99/mo or $59.99/yr
                </div>
              </div>
              <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
                <button
                  type="button"
                  onClick={async () => {
                    const { data: { session } } = await supabase.auth.getSession();
                    if (!session) return;
                    const result = await createCheckoutSession({ token: session.access_token, plan: 'monthly' });
                    if (result.url) window.location.href = result.url;
                  }}
                  style={{ flex: 1, background: '#fff', color: '#000', border: 'none', borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: 'pointer' }}
                >
                  $6.99/mo
                </button>
                <button
                  type="button"
                  onClick={async () => {
                    const { data: { session } } = await supabase.auth.getSession();
                    if (!session) return;
                    const result = await createCheckoutSession({ token: session.access_token, plan: 'yearly' });
                    if (result.url) window.location.href = result.url;
                  }}
                  style={{ flex: 1, background: 'transparent', color: '#fff', border: '1px solid rgba(255,255,255,0.2)', borderRadius: 12, padding: '12px 0', fontSize: 14, fontWeight: 700, cursor: 'pointer' }}
                >
                  $59.99/yr
                </button>
              </div>
            </div>
            <div style={{
              marginTop: 16, paddingTop: 16,
              borderTop: '1px solid rgba(255,255,255,0.06)',
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: 8,
            }}>
              {['Unlimited items', 'Unlimited AI scans', 'Share spaces', 'Spreadsheet import'].map((f) => (
                <div key={f} style={{ fontFamily: "var(--font-dm-sans, sans-serif)", fontSize: 13, color: 'rgba(255,255,255,0.45)' }}>
                  <span style={{ color: 'rgba(167,139,250,0.7)' }}>✓ </span>{f}
                </div>
              ))}
            </div>
          </div>
        )}
        {isPro === true && (
          <div style={{
            background: 'rgba(34,197,94,0.04)',
            border: '1px solid rgba(34,197,94,0.15)',
            borderRadius: 16,
            padding: '16px 24px',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}>
            <span style={{ color: '#22c55e', fontSize: 18 }}>✓</span>
            <div>
              <div style={{ color: 'white', fontWeight: 600, fontSize: 14 }}>FindEZ Pro — Active</div>
              <div style={{ color: '#a1a1a6', fontSize: 12 }}>Unlimited access to all features</div>
            </div>
          </div>
        )}
        {isPro === null && (
          <div style={{ height: 80, background: '#0a0a0a', borderRadius: 16, border: '1px solid #1c1c1e' }} />
        )}
      </div>
    </div>
  );
}
