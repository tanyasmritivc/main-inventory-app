"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import type { InventoryItem } from "@/lib/api";
import {
  aiCommand,
  checkUsage,
  getMyLimits,
  getMyProfile,
  searchItems,
} from "@/lib/api";
import { PILOT_COPY } from "@/lib/pilot";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  dashboardAiInputPlaceholder,
  dashboardSuggestedPrompts,
  type UsageType,
} from "@/lib/personalization";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { UpgradeGate } from "@/components/site/upgrade-gate";
import SpecularButton from "@/components/ui/SpecularButton";

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

function renderMarkdown(text: string): ReactNode {
  const lines = text.split('\n');
  const elements: ReactNode[] = [];
  let key = 0;

  function parseLine(raw: string): ReactNode {
    const parts = raw.split(/(\*\*[^*]+\*\*)/g);
    return parts.map((part, idx) => {
      if (part.startsWith('**') && part.endsWith('**')) {
        return <strong key={idx} style={{ color: '#f5f5f7', fontWeight: 600 }}>{part.slice(2, -2)}</strong>;
      }
      return <span key={idx}>{part}</span>;
    });
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? '';

    if (line.trim() === '') {
      elements.push(<div key={key++} style={{ height: '6px' }} />);
      continue;
    }

    if (/^[-•]\s/.test(line.trim())) {
      const content = line.trim().replace(/^[-•]\s/, '');
      elements.push(
        <div key={key++} style={{ display: 'flex', gap: '8px', marginBottom: '3px', paddingLeft: '4px' }}>
          <span style={{ color: '#6e6e73', flexShrink: 0, marginTop: '1px' }}>·</span>
          <span style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.55, letterSpacing: '-0.01em' }}>{parseLine(content)}</span>
        </div>
      );
      continue;
    }

    if (/^\d+\.\s/.test(line.trim())) {
      const match = line.trim().match(/^(\d+)\.\s(.*)/);
      if (match) {
        elements.push(
          <div key={key++} style={{ display: 'flex', gap: '8px', marginBottom: '3px', paddingLeft: '4px' }}>
            <span style={{ color: '#6e6e73', flexShrink: 0, minWidth: '16px', fontSize: '12px' }}>{match[1]}.</span>
            <span style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.55, letterSpacing: '-0.01em' }}>{parseLine(match[2] ?? '')}</span>
          </div>
        );
        continue;
      }
    }

    elements.push(
      <div key={key++} style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.6, letterSpacing: '-0.01em', marginBottom: '2px' }}>
        {parseLine(line)}
      </div>
    );
  }

  return <div>{elements}</div>;
}

export function DashboardClient() {
  const supabase = createSupabaseBrowserClient();

  const [token, setToken] = useState<string | null>(null);
  const [usageType, setUsageType] = useState<UsageType | null>(null);
  const [userFirstName, setUserFirstName] = useState('');
  const [allItems, setAllItems] = useState<InventoryItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [aiSending, setAiSending] = useState(false);
  const [aiInput, setAiInput] = useState('');
  const [aiMessages, setAiMessages] = useState<Array<{ role: 'user' | 'assistant'; text: string }>>([]);
  const [aiStatus, setAiStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [importOpen, setImportOpen] = useState(false);
  const [importStep, setImportStep] = useState<'pick' | 'upload'>('pick');
  const [importSpaceInput, setImportSpaceInput] = useState('');

  const [upgradeGate, setUpgradeGate] = useState<{ open: boolean; feature: string; current: number; limit: number; message: string }>({ open: false, feature: '', current: 0, limit: 0, message: '' });
  const [pilotMode, setPilotMode] = useState(false);
  const [pilotNotice, setPilotNotice] = useState<string | null>(null);

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === 'string') return err;
    return fallback;
  }

  function handleApiError(err: any): boolean {
    if (err?.limitExceeded && err?.limitData) {
      setUpgradeGate({ open: true, feature: err.limitData.feature, current: err.limitData.current, limit: err.limitData.limit, message: err.limitData.message });
      return true;
    }
    if (err?.status === 403 || err?.upgrade_required) {
      // checkAndGate already showed the gate before the API call; swallow the 403 silently
      return true;
    }
    return false;
  }

  const checkAndGate = async (feature: string): Promise<boolean> => {
    try {
      const t = token || (await refreshToken());
      if (!t) return true;
      const res = await checkUsage({ token: t, feature });
      if (!res || typeof res !== 'object') return true;
      if (!res.allowed) {
        setUpgradeGate({
          open: true,
          feature,
          current: res.current ?? 0,
          limit: res.limit ?? 0,
          message: `You've used ${res.current ?? 0} of ${res.limit ?? 0} free ${res.feature_label ?? feature.replace(/_/g, ' ')}s this month.`,
        });
        return false;
      }
      return true;
    } catch {
      return true;
    }
  };

  async function refreshToken(): Promise<string> {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        setToken(session.access_token);
        return session.access_token;
      }
    } catch (_) {}
    return '';
  }

  async function loadUsageType() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const email = user.email ?? '';
      try {
        const t = await refreshToken();
        if (t) {
          const prof = await getMyProfile({ token: t });
          const name = (prof.display_name ?? '').trim();
          setUserFirstName(name || (email ? email.split('@')[0] : ''));
        } else {
          setUserFirstName(email ? email.split('@')[0] : '');
        }
      } catch {
        setUserFirstName(email ? email.split('@')[0] : '');
      }
      setUsageType(null);
    } catch {
      setUsageType(null);
    }
  }

  async function loadItems(currentToken?: string) {
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      if (!t) return;
      const res = await searchItems({ token: t, query: '' });
      setAllItems(res.items ?? []);
    } catch (err: unknown) {
      setError(errorMessage(err, 'Failed to load items'));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    refreshToken().then((t) => {
      void loadUsageType();
      if (t) {
        getMyLimits({ token: t }).then((l) => {
          if (l.pilot_mode) {
            setPilotMode(true);
            setPilotNotice(l.pilot_notice ?? null);
          }
        }).catch(() => {});
      }
      return loadItems(t);
    }).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onSendAiMessage() {
    const text = aiInput.trim();
    if (!text || aiSending) return;
    const allowed = await checkAndGate('ai_chat');
    if (!allowed) return;
    setError(null);
    setAiSending(true);
    setAiStatus('Thinking…');
    setAiMessages((prev) => [...prev, { role: 'user', text }]);
    setAiInput('');
    try {
      setAiStatus('Checking your inventory…');
      const t = token || (await refreshToken());
      if (!t) return;
      const res = await aiCommand({ token: t, message: text });
      setAiMessages((prev) => [
        ...prev,
        { role: 'assistant', text: (res.assistant_message || '').trim() || 'Done.' },
      ]);
    } catch (err: unknown) {
      setError(errorMessage(err, 'AI request failed'));
    } finally {
      setAiSending(false);
      setAiStatus(null);
    }
  }

  const spacesData = useMemo(() => {
    const map = new Map<string, { count: number; lowStockCount: number }>();
    for (const item of allItems) {
      const name = (item.location ?? '').trim() || 'Unsorted';
      const existing = map.get(name) ?? { count: 0, lowStockCount: 0 };
      existing.count += 1;
      if (item.quantity <= 1) existing.lowStockCount += 1;
      map.set(name, existing);
    }
    return Array.from(map.entries())
      .map(([name, data]) => ({ name, ...data }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [allItems]);

  const spaceNames = useMemo(() => spacesData.map((s) => s.name), [spacesData]);

  function openImport(spaceName?: string) {
    setImportSpaceInput(spaceName ?? spaceNames[0] ?? '');
    setImportStep(spaceName ? 'upload' : 'pick');
    setImportOpen(true);
  }

  function closeImport() {
    setImportOpen(false);
    setImportStep('pick');
    setImportSpaceInput('');
  }

  const handleSend = () => void onSendAiMessage();

  return (
    <>
      {pilotMode && (
        <div style={{
          background: 'rgba(52,211,153,0.08)',
          border: '1px solid rgba(52,211,153,0.25)',
          borderRadius: 12,
          padding: '12px 18px',
          marginBottom: 16,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
        }}>
          <span style={{ fontSize: 16 }}>🚀</span>
          <div>
            <span style={{ color: '#34d399', fontWeight: 700, fontSize: 13 }}>Free Pilot</span>
            <span style={{ color: 'rgba(255,255,255,0.55)', fontSize: 13, marginLeft: 8 }}>
              {pilotNotice ?? PILOT_COPY.notice}
            </span>
          </div>
        </div>
      )}

      <div style={{ position: 'relative', WebkitFontSmoothing: 'antialiased' as any }}>

        {/* Import button — top right */}
        <div style={{ position: 'absolute', top: '24px', right: '24px' }}>
          <button
            onClick={() => openImport()}
            style={{
              background: 'rgba(255,255,255,0.06)',
              border: '1px solid rgba(255,255,255,0.12)',
              borderRadius: '8px',
              color: 'rgba(255,255,255,0.7)',
              fontSize: '13px',
              fontWeight: 500,
              padding: '8px 16px',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
            }}
          >
            Import Spreadsheet
          </button>
        </div>

        {/* HERO SEARCH */}
        <div style={{ display: 'flex', flexDirection: 'column' as const, alignItems: 'center', justifyContent: 'center', minHeight: 'calc(100vh - 100px)', padding: '0 24px' }}>

          {/* Large heading */}
          <h1 style={{ fontFamily: 'Georgia, "Times New Roman", serif', fontWeight: 400, fontSize: 'clamp(1.6rem, 3.5vw, 2.4rem)', color: 'rgba(255,255,255,0.88)', letterSpacing: '-0.02em', textAlign: 'center' as const, marginBottom: '32px', margin: '0 0 32px' }}>
            What do you want to find?
          </h1>

          {/* Messages — shown above input when messages exist */}
          {aiMessages.length > 0 && (
            <div style={{ width: '100%', maxWidth: '680px', maxHeight: '400px', overflowY: 'auto' as const, marginBottom: '16px' }}>
              {aiStatus ? <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)', margin: '0 0 8px' }}>{aiStatus}</p> : null}
              <div style={{ display: 'flex', flexDirection: 'column' as const, gap: 4 }}>
                {aiMessages.map((m, idx) => (
                  <div
                    key={idx}
                    style={m.role === 'user' ? {
                      background: 'rgba(255,255,255,0.05)',
                      border: '1px solid rgba(255,255,255,0.08)',
                      borderRadius: '10px 10px 2px 10px',
                      padding: '10px 14px',
                      marginBottom: 8,
                      alignSelf: 'flex-end' as const,
                      maxWidth: '80%',
                    } : {
                      padding: '4px 0',
                      marginBottom: 8,
                      maxWidth: '100%',
                    }}
                  >
                    {m.role === 'assistant'
                      ? renderMarkdown(m.text)
                      : <div style={{ fontSize: '13px', color: '#f5f5f7', letterSpacing: '-0.01em' }}>{m.text}</div>
                    }
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Search input */}
          {aiStatus && aiMessages.length === 0 ? <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)', margin: '0 0 10px', textAlign: 'center' as const }}>{aiStatus}</p> : null}
          <div
            className="chat-box"
            style={{
              maxWidth: '580px',
              width: '100%',
              margin: '0 auto',
              background: 'transparent',
              border: '1px solid rgba(255,255,255,0.15)',
              borderRadius: '12px',
              padding: '14px 18px',
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
            }}
          >
            <input
              value={aiInput}
              onChange={(e) => setAiInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') void onSendAiMessage(); }}
              placeholder="Ask anything about your inventory..."
              className="ai-input"
              style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: 'white', fontSize: '15px' }}
            />
            <SpecularButton
              size="sm"
              radius={8}
              tint="#14b8a6"
              tintOpacity={0.15}
              blur={0}
              textColor="#ffffff"
              lineColor="#14b8a6"
              baseColor="#0d9488"
              intensity={1}
              shineSize={10}
              shineFade={40}
              thickness={1}
              speed={0.35}
              followMouse={true}
              proximity={200}
              disabled={aiSending || !aiInput.trim()}
              onClick={handleSend}
            >
              Send
            </SpecularButton>
          </div>
        </div>

      </div>

      {/* Import Spreadsheet dialog */}
      <Dialog open={importOpen} onOpenChange={(open) => { if (!open) closeImport(); }}>
        <DialogContent style={{ background: 'rgba(10,10,14,0.98)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: '16px', padding: '28px', maxWidth: '520px', width: '100%', backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)', WebkitFontSmoothing: 'antialiased' as any }}>
          {importStep === 'pick' ? (
            <div>
              <div style={{ fontSize: '17px', fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7', marginBottom: '8px' }}>
                Import Spreadsheet
              </div>
              <div style={{ fontSize: '13px', color: '#6e6e73', marginBottom: '20px', letterSpacing: '-0.01em' }}>
                Which space should items be imported into?
              </div>
              <input
                list="import-spaces-list"
                value={importSpaceInput}
                onChange={(e) => setImportSpaceInput(e.target.value)}
                placeholder="e.g. Garage, Kitchen, Office…"
                style={{ width: '100%', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.12)', borderRadius: '8px', padding: '10px 14px', fontSize: '13px', color: '#f5f5f7', outline: 'none', letterSpacing: '-0.01em', boxSizing: 'border-box' as const, marginBottom: '20px' }}
                onFocus={(e) => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.28)'; }}
                onBlur={(e) => { e.currentTarget.style.borderColor = 'rgba(255,255,255,0.12)'; }}
                autoFocus
              />
              {spaceNames.length > 0 && (
                <datalist id="import-spaces-list">
                  {spaceNames.map((name) => <option key={name} value={name} />)}
                </datalist>
              )}
              <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                <button type="button" onClick={closeImport} style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.10)', borderRadius: '8px', padding: '9px 18px', fontSize: '13px', color: '#a1a1a6', cursor: 'pointer' }}>
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={async () => {
                    const allowed = await checkAndGate('spreadsheet_import');
                    if (!allowed) return;
                    setImportStep('upload');
                  }}
                  disabled={!importSpaceInput.trim()}
                  style={{ background: '#fff', color: '#000', border: 'none', borderRadius: '8px', padding: '9px 22px', fontSize: '13px', fontWeight: 590, cursor: !importSpaceInput.trim() ? 'not-allowed' : 'pointer', letterSpacing: '-0.015em', opacity: !importSpaceInput.trim() ? 0.4 : 1 }}
                >
                  Continue →
                </button>
              </div>
            </div>
          ) : (
            <div>
              <div style={{ fontSize: '17px', fontWeight: 590, letterSpacing: '-0.025em', color: '#f5f5f7', marginBottom: '4px' }}>
                Import into &ldquo;{importSpaceInput}&rdquo;
              </div>
              <div style={{ fontSize: '12px', color: '#6e6e73', marginBottom: '20px' }}>
                <button
                  type="button"
                  onClick={() => setImportStep('pick')}
                  style={{ color: '#6e6e73', background: 'none', border: 'none', cursor: 'pointer', padding: 0, fontSize: '12px', textDecoration: 'underline' }}
                >
                  Change space
                </button>
              </div>
              {token ? (
                <SpreadsheetImportModal
                  spaceName={importSpaceInput.trim()}
                  token={token}
                  onSuccess={(count) => {
                    setSuccess(`${count} item${count !== 1 ? 's' : ''} imported into “${importSpaceInput}”.`);
                    closeImport();
                    void loadItems();
                  }}
                />
              ) : (
                <div style={{ fontSize: 13, color: '#6e6e73', textAlign: 'center' as const, padding: '24px 0' }}>Loading…</div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>

      <UpgradeGate
        open={upgradeGate.open}
        onClose={() => setUpgradeGate((g) => ({ ...g, open: false }))}
        feature={upgradeGate.feature}
        current={upgradeGate.current}
        limit={upgradeGate.limit}
        message={upgradeGate.message}
        isPilot={pilotMode}
      />
    </>
  );
}
