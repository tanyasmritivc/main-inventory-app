'use client'
import Link from 'next/link'
import { BILLING_PLANS, PLANS_NOTICE } from '@/lib/billing-plans'

interface UpgradeGateProps {
  open: boolean
  onClose: () => void
  feature: string
  current: number
  limit: number
  message?: string
  isPilot?: boolean
}

const FEATURE_ICONS: Record<string, string> = {
  ai_chat: '💬',
  photo_scan: '📷',
  spreadsheet_import: '📊',
  spaces: '📦',
}

export function UpgradeGate({ open, onClose, feature, current, limit, message, isPilot }: UpgradeGateProps) {
  if (!open || isPilot) return null

  const icon = FEATURE_ICONS[feature] ?? '⭐'

  return (
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: 'rgba(0,0,0,0.75)',
        backdropFilter: 'blur(10px)',
        WebkitBackdropFilter: 'blur(10px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '24px',
        animation: 'fadeIn 0.2s ease',
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: 'var(--light-panel)',
          border: '1px solid rgba(0,0,0,0.10)',
          borderRadius: '20px',
          padding: '32px 28px',
          maxWidth: '400px',
          width: '100%',
          backdropFilter: 'blur(24px)',
          boxShadow: '0 32px 80px rgba(0,0,0,0.7), 0 0 0 1px rgba(0,0,0,0.05)',
          fontFamily: "'Inter', -apple-system, sans-serif",
          WebkitFontSmoothing: 'antialiased',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* Icon */}
        <div style={{
          width: '52px', height: '52px', borderRadius: '14px',
          background: 'rgba(255,214,10,0.10)',
          border: '1px solid rgba(255,214,10,0.20)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: '24px', margin: '0 auto 18px',
        }}>
          {icon}
        </div>

        {/* Title */}
        <h2 style={{
          fontSize: '20px', fontWeight: 700, letterSpacing: '-0.035em',
          color: 'var(--text-primary)', textAlign: 'center', margin: '0 0 8px',
        }}>
          Usage limit reached
        </h2>

        {/* Usage indicator */}
        <p style={{
          fontSize: '13px', color: 'var(--text-secondary)', textAlign: 'center',
          lineHeight: 1.55, margin: '0 0 6px', letterSpacing: '-0.01em',
        }}>
          {message ?? `Current usage: ${current} of ${limit} (${feature.replace(/_/g, ' ')}).`}
        </p>

        {/* Progress bar */}
        <div style={{
          height: '4px', background: 'rgba(0,0,0,0.08)',
          borderRadius: '2px', margin: '14px 0 20px', overflow: 'hidden',
        }}>
          <div style={{
            height: '100%',
            width: `${limit > 0 ? Math.max(0, Math.min(100, (current / limit) * 100)) : 100}%`,
            background: 'var(--brand-accent)',
            borderRadius: '2px',
            transition: 'width 0.4s ease',
          }} />
        </div>

        {/* Divider */}
        <div style={{ height: '1px', background: 'rgba(0,0,0,0.07)', margin: '0 0 18px' }} />

        {/* Planned allowance */}
        <div style={{ marginBottom: '22px' }}>
          <div style={{
            fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em',
            textTransform: 'uppercase', color: 'var(--light-muted)', marginBottom: '12px',
          }}>
            Planned Plus allowance
          </div>
          {BILLING_PLANS[1].features.map(text => ({ icon: '✓', text })).map(f => (
            <div key={f.text} style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: '6px 0',
              borderBottom: '1px solid rgba(0,0,0,0.04)',
            }}>
              <span style={{ fontSize: '14px', flexShrink: 0 }}>{f.icon}</span>
              <span style={{ fontSize: '12px', color: 'var(--text-secondary)', letterSpacing: '-0.01em' }}>{f.text}</span>
            </div>
          ))}
        </div>

        {/* CTA */}
        <Link
          href="/pricing"
          style={{
            display: 'block',
            background: 'var(--control-primary)',
            color: 'var(--control-on-primary)',
            border: 'none',
            borderRadius: '10px',
            padding: '13px',
            fontSize: '14px',
            fontWeight: 600,
            textAlign: 'center',
            textDecoration: 'none',
            letterSpacing: '-0.02em',
            marginBottom: '10px',
            transition: 'opacity 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.opacity = '0.88'}
          onMouseLeave={e => e.currentTarget.style.opacity = '1'}
        >
          Compare Free, Plus and Team
        </Link>

        <button
          onClick={onClose}
          style={{
            display: 'block',
            width: '100%',
            background: 'rgba(0,0,0,0.05)',
            border: '1px solid rgba(0,0,0,0.10)',
            borderRadius: '10px',
            padding: '12px',
            fontSize: '13px',
            color: 'var(--text-secondary)',
            cursor: 'pointer',
            fontFamily: 'inherit',
            letterSpacing: '-0.01em',
            transition: 'background 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = 'rgba(0,0,0,0.09)'}
          onMouseLeave={e => e.currentTarget.style.background = 'rgba(0,0,0,0.05)'}
        >
          Maybe later
        </button>

        {/* Reset note */}
        <p style={{
          fontSize: '11px', color: 'var(--light-muted)', textAlign: 'center',
          margin: '14px 0 0', letterSpacing: '-0.005em',
        }}>
          {PLANS_NOTICE}
        </p>
      </div>
    </div>
  )
}
