'use client';

import React from 'react';

// Shared style constants
export const DS = {
  // Colors
  bg: '#000000',
  s1: '#0a0a0a',
  s2: '#111113',
  s3: '#1c1c1e',
  b1: '#1c1c1e',
  b2: '#2c2c2e',
  b3: '#3a3a3c',
  t1: '#f5f5f7',
  t2: '#a1a1a6',
  t3: '#6e6e73',
  t4: '#3a3a3c',
  white: '#ffffff',
  green: '#32d74b',
  yellow: '#ffd60a',
  red: '#ff453a',
  blue: '#6495ed',

  // Typography
  font: "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif",
  mono: "'SF Mono', ui-monospace, 'Cascadia Code', monospace",

  // Common styles
  card: {
    background: 'rgba(255,255,255,0.02)',
    border: '1px solid rgba(255,255,255,0.08)',
    borderRadius: '12px',
    backdropFilter: 'blur(12px)',
    WebkitBackdropFilter: 'blur(12px)',
  } as React.CSSProperties,

  input: {
    background: 'rgba(255,255,255,0.04)',
    border: '1px solid rgba(255,255,255,0.10)',
    borderRadius: '8px',
    padding: '10px 14px',
    fontSize: '13px',
    color: '#f5f5f7',
    outline: 'none',
    fontFamily: "'Inter', -apple-system, sans-serif",
    letterSpacing: '-0.01em',
    width: '100%',
    transition: 'border-color 0.15s',
  } as React.CSSProperties,

  btnPrimary: {
    background: '#ffffff',
    color: '#000000',
    border: 'none',
    borderRadius: '8px',
    padding: '10px 20px',
    fontSize: '13px',
    fontWeight: 510,
    cursor: 'pointer',
    fontFamily: "'Inter', -apple-system, sans-serif",
    letterSpacing: '-0.015em',
    transition: 'opacity 0.15s',
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
  } as React.CSSProperties,

  btnGhost: {
    background: 'rgba(255,255,255,0.05)',
    border: '1px solid rgba(255,255,255,0.10)',
    borderRadius: '8px',
    padding: '9px 16px',
    fontSize: '13px',
    fontWeight: 400,
    color: '#a1a1a6',
    cursor: 'pointer',
    fontFamily: "'Inter', -apple-system, sans-serif",
    letterSpacing: '-0.012em',
    backdropFilter: 'blur(8px)',
    transition: 'background 0.15s, border-color 0.15s',
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
  } as React.CSSProperties,

  btnDanger: {
    background: 'transparent',
    border: 'none',
    color: '#ff453a',
    fontSize: '12px',
    cursor: 'pointer',
    fontFamily: "'Inter', -apple-system, sans-serif",
    padding: '0',
  } as React.CSSProperties,

  label: {
    fontSize: '10px',
    fontWeight: 510,
    letterSpacing: '0.08em',
    textTransform: 'uppercase' as const,
    color: '#6e6e73',
    marginBottom: '8px',
    display: 'block',
  } as React.CSSProperties,

  fieldLabel: {
    fontSize: '12px',
    fontWeight: 510,
    color: '#a1a1a6',
    letterSpacing: '-0.01em',
    marginBottom: '4px',
    display: 'block',
  } as React.CSSProperties,

  modal: {
    background: 'rgba(12,12,16,0.97)',
    border: '1px solid rgba(255,255,255,0.10)',
    borderRadius: '16px',
    padding: '28px',
    backdropFilter: 'blur(24px)',
    WebkitBackdropFilter: 'blur(24px)',
    boxShadow: '0 24px 64px rgba(0,0,0,0.6)',
  } as React.CSSProperties,

  modalTitle: {
    fontSize: '17px',
    fontWeight: 590,
    letterSpacing: '-0.025em',
    color: '#f5f5f7',
    marginBottom: '20px',
  } as React.CSSProperties,

  divider: {
    height: '1px',
    background: 'rgba(255,255,255,0.06)',
    margin: '16px 0',
    border: 'none',
  } as React.CSSProperties,

  pill: (active: boolean) => ({
    background: active ? '#1c1c1e' : 'rgba(255,255,255,0.03)',
    color: active ? '#fff' : '#6e6e73',
    border: active ? '1px solid #2c2c2e' : '1px solid rgba(255,255,255,0.07)',
    borderRadius: '99px',
    padding: '4px 12px',
    fontSize: '11px',
    cursor: 'pointer',
    fontFamily: "'Inter', -apple-system, sans-serif",
    transition: 'all 0.15s',
  }) as React.CSSProperties,
};

// Upgrade gate modal component
interface UpgradeGateProps {
  open: boolean;
  onClose: () => void;
  feature: string;
  limit?: string;
}

export function UpgradeGate({ open, onClose, feature, limit }: UpgradeGateProps) {
  if (!open) return null;
  return (
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: 'rgba(0,0,0,0.7)',
        backdropFilter: 'blur(8px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '24px',
      }}
      onClick={onClose}
    >
      <div
        style={{
          ...DS.modal,
          maxWidth: '400px',
          width: '100%',
          textAlign: 'center',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Icon */}
        <div style={{
          width: '48px', height: '48px', borderRadius: '12px',
          background: 'rgba(255,214,10,0.10)',
          border: '1px solid rgba(255,214,10,0.20)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: '22px', margin: '0 auto 16px',
        }}>⭐</div>

        <div style={{ fontSize: '18px', fontWeight: 700, letterSpacing: '-0.03em', color: '#f5f5f7', marginBottom: '8px' }}>
          Upgrade to Pro
        </div>
        <div style={{ fontSize: '13px', color: '#a1a1a6', lineHeight: 1.55, marginBottom: '6px', letterSpacing: '-0.01em' }}>
          You&apos;ve reached the limit for <strong style={{ color: '#f5f5f7' }}>{feature}</strong>.
        </div>
        {limit && (
          <div style={{ fontSize: '12px', color: '#6e6e73', marginBottom: '20px' }}>{limit}</div>
        )}
        <hr style={DS.divider} />
        <div style={{ display: 'grid', gap: '8px', marginBottom: '20px', textAlign: 'left' }}>
          {[
            '✦ Unlimited AI chat messages',
            '✦ Unlimited photo scans',
            '✦ Unlimited items & spaces',
            '✦ Spreadsheet import',
            '✦ Priority support',
          ].map((f) => (
            <div key={f} style={{ fontSize: '13px', color: '#a1a1a6', letterSpacing: '-0.01em' }}>{f}</div>
          ))}
        </div>
        <a
          href="/upgrade"
          style={{
            ...DS.btnPrimary,
            display: 'block',
            textAlign: 'center',
            textDecoration: 'none',
            width: '100%',
            padding: '12px',
            fontSize: '14px',
            marginBottom: '10px',
            boxSizing: 'border-box',
          }}
        >
          Upgrade to Pro — $9/month
        </a>
        <button onClick={onClose} style={{ ...DS.btnGhost, width: '100%', justifyContent: 'center' }}>
          Maybe later
        </button>
      </div>
    </div>
  );
}
