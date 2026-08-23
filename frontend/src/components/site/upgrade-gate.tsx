'use client'
import Link from 'next/link'

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

const FEATURE_TIPS: Record<string, string> = {
  ai_chat: 'Ask unlimited questions about your inventory.',
  photo_scan: 'Scan unlimited photos and receipts.',
  spreadsheet_import: 'Import unlimited spreadsheets.',
  spaces: 'Create unlimited spaces.',
}

export function UpgradeGate({ open, onClose, feature, current, limit, message, isPilot }: UpgradeGateProps) {
  if (!open || isPilot) return null

  const icon = FEATURE_ICONS[feature] ?? '⭐'
  const tip = FEATURE_TIPS[feature] ?? ''

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
          background: 'rgba(12,12,16,0.98)',
          border: '1px solid rgba(255,255,255,0.10)',
          borderRadius: '20px',
          padding: '32px 28px',
          maxWidth: '400px',
          width: '100%',
          backdropFilter: 'blur(24px)',
          boxShadow: '0 32px 80px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.05)',
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
          color: '#f5f5f7', textAlign: 'center', margin: '0 0 8px',
        }}>
          You&apos;ve hit your free limit
        </h2>

        {/* Usage indicator */}
        <p style={{
          fontSize: '13px', color: '#a1a1a6', textAlign: 'center',
          lineHeight: 1.55, margin: '0 0 6px', letterSpacing: '-0.01em',
        }}>
          {message ?? `You've used ${current} of ${limit} free ${feature.replace(/_/g, ' ')}s this month.`}
        </p>

        {/* Progress bar */}
        <div style={{
          height: '4px', background: 'rgba(255,255,255,0.08)',
          borderRadius: '2px', margin: '14px 0 20px', overflow: 'hidden',
        }}>
          <div style={{
            height: '100%',
            width: `${Math.min(100, (current / limit) * 100)}%`,
            background: '#a78bfa',
            borderRadius: '2px',
            transition: 'width 0.4s ease',
          }} />
        </div>

        {/* Divider */}
        <div style={{ height: '1px', background: 'rgba(255,255,255,0.07)', margin: '0 0 18px' }} />

        {/* Pro features */}
        <div style={{ marginBottom: '22px' }}>
          <div style={{
            fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em',
            textTransform: 'uppercase', color: '#6e6e73', marginBottom: '12px',
          }}>
            FindEZ Pro includes
          </div>
          {[
            { icon: '💬', text: '20 → Unlimited AI chat messages' },
            { icon: '📷', text: '5 → Unlimited photo scans' },
            { icon: '📊', text: '2 → Unlimited spreadsheet imports' },
            { icon: '📦', text: '3 → Unlimited spaces' },
          ].map(f => (
            <div key={f.text} style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: '6px 0',
              borderBottom: '1px solid rgba(255,255,255,0.04)',
            }}>
              <span style={{ fontSize: '14px', flexShrink: 0 }}>{f.icon}</span>
              <span style={{ fontSize: '12px', color: '#a1a1a6', letterSpacing: '-0.01em' }}>{f.text}</span>
            </div>
          ))}
        </div>

        {/* CTA */}
        <Link
          href="/upgrade"
          style={{
            display: 'block',
            background: '#ffffff',
            color: '#000000',
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
          Upgrade to Pro — $9/month
        </Link>

        <button
          onClick={onClose}
          style={{
            display: 'block',
            width: '100%',
            background: 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,255,255,0.10)',
            borderRadius: '10px',
            padding: '12px',
            fontSize: '13px',
            color: '#a1a1a6',
            cursor: 'pointer',
            fontFamily: 'inherit',
            letterSpacing: '-0.01em',
            transition: 'background 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.09)'}
          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.05)'}
        >
          Maybe later
        </button>

        {/* Reset note */}
        <p style={{
          fontSize: '11px', color: '#3a3a3c', textAlign: 'center',
          margin: '14px 0 0', letterSpacing: '-0.005em',
        }}>
          Free limits reset on the 1st of each month.
        </p>
      </div>
    </div>
  )
}
