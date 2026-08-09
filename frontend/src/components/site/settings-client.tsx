"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { getMyLimits, getMyProfile, updateProfile, createBillingPortal, type LimitsResponse } from "@/lib/api";

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);
  const [limits, setLimits] = useState<LimitsResponse | null>(null);
  const [limitsError, setLimitsError] = useState(false);
  const [portalLoading, setPortalLoading] = useState(false);
  const [profile, setProfile] = useState<{ display_name: string; contact_email: string; avatar_color: string } | null>(null);
  const [editingName, setEditingName] = useState('');
  const [editingEmail, setEditingEmail] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      const token = data.session?.access_token;
      if (!token) return;
      getMyLimits({ token })
        .then((l) => setLimits(l))
        .catch(() => setLimitsError(true));
      getMyProfile({ token }).then((prof) => {
        setProfile(prof);
        setEditingName(prof.display_name ?? '');
        setEditingEmail(prof.contact_email ?? '');
      }).catch(() => {});
    }).catch(() => {});
  }, [supabase]);

  async function handleBillingPortal() {
    setPortalLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) return;
      const result = await createBillingPortal({ token: session.access_token });
      if (result.url) window.location.href = result.url;
    } catch (_) {
      // silently fail — portal link not critical
    } finally {
      setPortalLoading(false);
    }
  }

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
      {/* PLAN & USAGE */}
      <div style={{ marginBottom: 32, marginTop: 32 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <p style={{ fontSize: 10, fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', margin: 0 }}>
            Plan &amp; Usage
          </p>
          {limits && (
            <TierBadge tier={limits.tier} />
          )}
        </div>

        {/* Skeleton */}
        {!limits && !limitsError && (
          <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: 16, height: 160 }} />
        )}

        {/* Error fallback */}
        {limitsError && (
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 16, padding: '16px 20px', color: 'rgba(255,255,255,0.3)', fontSize: 13 }}>
            Could not load plan info. <button type="button" onClick={() => {
              setLimitsError(false);
              supabase.auth.getSession().then(({ data }) => {
                const token = data.session?.access_token;
                if (!token) return;
                getMyLimits({ token }).then(setLimits).catch(() => setLimitsError(true));
              });
            }} style={{ background: 'none', border: 'none', color: '#a78bfa', cursor: 'pointer', padding: 0, fontSize: 13 }}>Retry</button>
          </div>
        )}

        {/* Active plan info */}
        {limits && (
          <div style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 16, overflow: 'hidden' }}>
            {/* Usage bars */}
            <div style={{ padding: '18px 20px', display: 'flex', flexDirection: 'column', gap: 16 }}>
              <UsageBar label="Items" used={limits.items.used} max={limits.items.max} />
              <UsageBar label="Spaces" used={limits.spaces.used} max={limits.spaces.max} />
              <UsageBar label="AI chats" used={limits.chats.used} max={limits.chats.max} resetsAt={limits.chats.resets_at} />
              <UsageBar label="Photo scans" used={limits.scans.used} max={limits.scans.max} resetsAt={limits.scans.resets_at} />
            </div>

            <div style={{ height: 1, background: 'rgba(255,255,255,0.06)' }} />

            {/* CTA row */}
            <div style={{ padding: '14px 20px' }}>
              {limits.tier === 'free' ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
                  <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.4)' }}>
                    Unlock unlimited everything
                  </span>
                  <Link
                    href="/pricing"
                    style={{
                      background: '#fff',
                      color: '#000',
                      textDecoration: 'none',
                      borderRadius: 99,
                      padding: '8px 18px',
                      fontSize: 13,
                      fontWeight: 700,
                      flexShrink: 0,
                    }}
                  >
                    Upgrade
                  </Link>
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
                  <div>
                    <div style={{ fontSize: 13, color: 'white', fontWeight: 500 }}>
                      FindEZ {limits.tier === 'team_member' ? 'Team' : 'Pro'} — Active
                    </div>
                    {limits.plan?.renews_at && (
                      <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.35)', marginTop: 2 }}>
                        Renews {new Date(limits.plan.renews_at).toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' })}
                      </div>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => void handleBillingPortal()}
                    disabled={portalLoading}
                    style={{
                      background: 'transparent',
                      color: 'rgba(255,255,255,0.55)',
                      border: '1px solid rgba(255,255,255,0.12)',
                      borderRadius: 99,
                      padding: '8px 16px',
                      fontSize: 13,
                      cursor: portalLoading ? 'wait' : 'pointer',
                      flexShrink: 0,
                    }}
                  >
                    {portalLoading ? 'Opening…' : 'Manage billing'}
                  </button>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Helper components ──────────────────────────────────────────────────────────

function TierBadge({ tier }: { tier: 'free' | 'pro' | 'team_member' }) {
  const configs: Record<string, { label: string; bg: string; color: string }> = {
    free: { label: 'Free', bg: 'rgba(255,255,255,0.06)', color: 'rgba(255,255,255,0.4)' },
    pro: { label: 'Pro', bg: 'rgba(167,139,250,0.12)', color: '#a78bfa' },
    team_member: { label: 'Team', bg: 'rgba(245,158,11,0.12)', color: '#f59e0b' },
  };
  const c = configs[tier] ?? configs.free;
  return (
    <span style={{
      background: c.bg,
      color: c.color,
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
      borderRadius: 99,
      padding: '3px 9px',
    }}>
      {c.label}
    </span>
  );
}

function UsageBar({
  label,
  used,
  max,
  resetsAt,
}: {
  label: string;
  used: number;
  max: number | null;
  resetsAt?: string;
}) {
  const pct = max !== null ? Math.min(1, used / max) : 0;
  const nearLimit = max !== null && pct >= 0.85;
  const barColor = nearLimit ? '#ff9f0a' : '#a78bfa';

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 5 }}>
        <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', fontWeight: 500 }}>{label}</span>
        <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.3)', fontVariantNumeric: 'tabular-nums' }}>
          {used.toLocaleString()}
          {max !== null ? ` / ${max.toLocaleString()}` : ''}
          {max === null ? ' — unlimited' : ''}
          {resetsAt && max !== null ? ` · resets ${new Date(resetsAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}` : ''}
        </span>
      </div>
      {max !== null && (
        <div style={{ height: 3, background: 'rgba(255,255,255,0.07)', borderRadius: 99, overflow: 'hidden' }}>
          <div
            style={{
              height: '100%',
              width: `${pct * 100}%`,
              background: barColor,
              borderRadius: 99,
              transition: 'width 400ms ease',
            }}
          />
        </div>
      )}
    </div>
  );
}
