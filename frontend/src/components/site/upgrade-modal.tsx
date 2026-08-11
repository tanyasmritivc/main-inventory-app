'use client';

import { useRouter } from 'next/navigation';

interface UpgradeModalProps {
  open: boolean;
  onClose: () => void;
  reason: 'item_limit' | 'scan_limit';
}

export function UpgradeModal({ open, onClose, reason }: UpgradeModalProps) {
  const router = useRouter();
  if (!open) return null;

  const config = {
    item_limit: {
      icon: '📦',
      title: "You've hit the 30-item limit",
      subtitle: 'Get a team plan for unlimited items, spaces, and AI scans.',
    },
    scan_limit: {
      icon: '📸',
      title: "You've used all 5 photo scans this month",
      subtitle: 'Get a team plan for hundreds of AI photo scans per season.',
    },
  }[reason];

  return (
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: 'rgba(0,0,0,0.75)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '24px',
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: '#0d0d0d',
          border: '1px solid rgba(255,255,255,0.10)',
          borderRadius: '20px',
          padding: '32px 28px',
          maxWidth: '420px', width: '100%',
          textAlign: 'center',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{
          width: 52, height: 52, borderRadius: '50%',
          background: 'rgba(167,139,250,0.12)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 20px', fontSize: 24,
        }}>
          {config.icon}
        </div>

        <h2 style={{
          fontFamily: 'var(--font-syne)', fontSize: 22,
          fontWeight: 700, color: '#fff', marginBottom: 10,
        }}>
          {config.title}
        </h2>

        <p style={{
          fontFamily: 'var(--font-dm-sans)', fontSize: 14,
          color: 'rgba(255,255,255,0.50)', marginBottom: 28,
          lineHeight: 1.6,
        }}>
          {config.subtitle}
        </p>

        <div style={{ display: 'flex', gap: 10, flexDirection: 'column' }}>
          <button
            onClick={() => router.push('/pricing')}
            style={{
              width: '100%', height: 48,
              background: '#fff', color: '#000',
              border: 'none', borderRadius: 99,
              fontFamily: 'var(--font-syne)', fontSize: 15,
              fontWeight: 600, cursor: 'pointer',
            }}
          >
            See team plans
          </button>

          <button
            onClick={onClose}
            style={{
              width: '100%', height: 44,
              background: 'transparent',
              color: 'rgba(255,255,255,0.35)',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 99,
              fontFamily: 'var(--font-dm-sans)', fontSize: 14,
              cursor: 'pointer',
            }}
          >
            Maybe later
          </button>
        </div>
      </div>
    </div>
  );
}
