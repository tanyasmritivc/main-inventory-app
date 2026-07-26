'use client'
import React, { useEffect, useState, Suspense } from 'react'
import Link from 'next/link'
import GradualBlur from '@/components/ui/GradualBlur'
import FloatingLines from '@/components/ui/FloatingLines'
import SpecularButton from '@/components/ui/SpecularButton'
import { AuthForm } from '@/components/site/auth-form'


export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false)
  const [authModal, setAuthModal] = useState<'signin' | 'signup' | null>(null)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const S: React.CSSProperties = {
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif",
    WebkitFontSmoothing: 'antialiased',
  }

  return (
    <div style={{ ...S, background: '#fff', color: '#0a0a0a', minHeight: '100vh' }}>

      {/* ── ANNOUNCEMENT BAR ── */}
      <div style={{
        background: 'rgba(20, 184, 166, 0.15)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        borderBottom: '1px solid rgba(20, 184, 166, 0.25)',
        color: 'rgba(255, 255, 255, 0.9)',
        textAlign: 'center',
        padding: '10px 24px',
        fontSize: '13px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '8px',
      }}>
        <span style={{ color: 'rgba(255, 255, 255, 0.9)' }}>FindEZ AI is now available on iOS.</span>
        <Link href="/signup" style={{ color: '#14b8a6', textDecoration: 'none', fontWeight: 500 }}>
          Get started free →
        </Link>
      </div>

      {/* ── NAV ── */}
      <nav style={{
        position: 'sticky',
        top: 0,
        zIndex: 100,
        background: scrolled ? 'rgba(255,255,255,0.92)' : '#fff',
        backdropFilter: scrolled ? 'blur(12px)' : 'none',
        borderBottom: '1px solid #e5e7eb',
        padding: '0 40px',
        height: '60px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        transition: 'all 0.2s ease',
      }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'baseline', gap: '8px' }}>
          <span style={{ fontSize: '16px', fontWeight: 600, letterSpacing: '-0.025em', color: '#0a0a0a' }}>
            FindEZ AI
          </span>
          <span style={{ fontSize: '12px', color: '#9ca3af', letterSpacing: '-0.01em', fontWeight: 400 }}>
            by AI Robots Inc
          </span>
        </div>

        {/* Nav links */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <a
            href="https://apps.apple.com/app/findez/id6746827458"
            target="_blank"
            rel="noopener noreferrer"
            style={{
              padding: '6px 14px',
              fontSize: '14px',
              fontWeight: 400,
              color: '#6b7280',
              textDecoration: 'none',
              borderRadius: '6px',
              transition: 'color 0.15s',
              letterSpacing: '-0.01em',
            }}
            onMouseEnter={e => (e.currentTarget.style.color = '#0a0a0a')}
            onMouseLeave={e => (e.currentTarget.style.color = '#6b7280')}
          >
            iOS App
          </a>
          <button
            onClick={() => setAuthModal('signin')}
            style={{
              padding: '6px 14px',
              fontSize: '14px',
              fontWeight: 400,
              color: '#6b7280',
              background: 'none',
              border: 'none',
              borderRadius: '6px',
              transition: 'color 0.15s',
              letterSpacing: '-0.01em',
              cursor: 'pointer',
            }}
            onMouseEnter={e => (e.currentTarget.style.color = '#0a0a0a')}
            onMouseLeave={e => (e.currentTarget.style.color = '#6b7280')}
          >
            Sign in
          </button>
          <button
            onClick={() => setAuthModal('signup')}
            style={{
              padding: '7px 16px',
              fontSize: '14px',
              fontWeight: 500,
              color: '#fff',
              background: '#0a0a0a',
              border: 'none',
              borderRadius: '6px',
              letterSpacing: '-0.01em',
              transition: 'opacity 0.15s',
              marginLeft: '4px',
              cursor: 'pointer',
            }}
            onMouseEnter={e => (e.currentTarget.style.opacity = '0.8')}
            onMouseLeave={e => (e.currentTarget.style.opacity = '1')}
          >
            Get started
          </button>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section style={{ background: '#fff', padding: 0 }}>
        {/* Floating inset hero card */}
        <div style={{
          position: 'relative',
          borderRadius: '20px',
          overflow: 'hidden',
          minHeight: '100vh',
          margin: '12px',
          width: 'calc(100% - 24px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}>
          {/* FloatingLines background - stays inside the box */}
          <div style={{ position: 'absolute', inset: 0, zIndex: 0 }}>
            <FloatingLines
              enabledWaves={['top', 'middle', 'bottom']}
              lineCount={8}
              lineDistance={8}
              bendRadius={8}
              bendStrength={-2}
              interactive={true}
              parallax={true}
              animationSpeed={1}
              linesGradient={['#1f8293', '#267e8c', '#08333b', '#2c5158']}
            />
          </div>

          {/* Hero content centered */}
          <div style={{ position: 'relative', zIndex: 1, textAlign: 'center', padding: '80px 60px', maxWidth: '900px' }}>
            <h1 style={{
              fontSize: 'clamp(42px, 6vw, 72px)',
              fontWeight: 600,
              letterSpacing: '-0.03em',
              lineHeight: 1.08,
              color: '#ffffff',
              marginBottom: '40px',
              maxWidth: '800px',
              margin: '0 auto 40px',
              fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif",
            }}>
              Your workshop<br />inventory assistant.
            </h1>

            <div style={{ marginTop: '48px', display: 'flex', justifyContent: 'center' }}>
              <SpecularButton
                size="lg"
                radius={18}
                tint="#ffffff"
                tintOpacity={0}
                blur={0}
                textColor="#f5f5f5"
                lineColor="#ffffff"
                baseColor="#525252"
                intensity={1}
                shineSize={10}
                shineFade={40}
                thickness={1}
                speed={0.35}
                followMouse={true}
                proximity={250}
                onClick={() => setAuthModal('signup')}
              >
                Get Started
              </SpecularButton>
            </div>
          </div>

          <GradualBlur
            target="parent"
            position="bottom"
            height="6rem"
            strength={2}
            divCount={5}
            curve="bezier"
            exponential={true}
            opacity={1}
            zIndex={2}
          />
        </div>
      </section>



      {/* ── FOOTER ── */}
      <footer style={{
        paddingTop: '80px',
        background: '#0a0a0a',
        borderTop: '1px solid rgba(255,255,255,0.08)',
        padding: '48px 40px 40px',
      }}>
        {/* Big footer text like Scale AI */}
        <div style={{
          fontSize: 'clamp(48px, 8vw, 100px)',
          fontWeight: 600,
          letterSpacing: '-0.04em',
          color: 'rgba(255,255,255,0.08)',
          lineHeight: 1,
          marginBottom: '48px',
          userSelect: 'none',
        }}>
          FindEZ AI
        </div>

        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap' as const,
          gap: '16px',
          paddingTop: '32px',
          borderTop: '1px solid rgba(255,255,255,0.08)',
        }}>
          <div>
            <span style={{ fontSize: '14px', fontWeight: 500, color: '#fff', letterSpacing: '-0.02em' }}>FindEZ AI</span>
            <span style={{ fontSize: '13px', color: 'rgba(255,255,255,0.3)', marginLeft: '8px', letterSpacing: '-0.01em' }}>
              a product of AI Robots Inc
            </span>
          </div>
          <span style={{ fontSize: '12px', color: 'rgba(255,255,255,0.3)', letterSpacing: '-0.005em' }}>
            © {new Date().getFullYear()} AI Robots Inc. All rights reserved.
          </span>
          <div style={{ display: 'flex', gap: '20px' }}>
            {['Privacy', 'Terms', 'iOS App'].map(l => (
              <a key={l} href="#" style={{
                fontSize: '13px',
                color: 'rgba(255,255,255,0.4)',
                textDecoration: 'none',
                letterSpacing: '-0.01em',
                transition: 'color 0.15s',
              }}
                onMouseEnter={e => (e.currentTarget.style.color = 'rgba(255,255,255,0.8)')}
                onMouseLeave={e => (e.currentTarget.style.color = 'rgba(255,255,255,0.4)')}
              >
                {l}
              </a>
            ))}
          </div>
        </div>
      </footer>

      {authModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.7)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
          onClick={(e) => { if (e.target === e.currentTarget) setAuthModal(null); }}
        >
          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setAuthModal(null)}
              style={{
                position: 'absolute',
                top: '-12px',
                right: '-12px',
                zIndex: 10,
                background: 'rgba(255,255,255,0.1)',
                border: '1px solid rgba(255,255,255,0.15)',
                borderRadius: '50%',
                width: '32px',
                height: '32px',
                color: 'white',
                cursor: 'pointer',
                fontSize: '16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              ×
            </button>
            <Suspense fallback={null}>
              <AuthForm
                mode={authModal}
                onToggleMode={(m) => setAuthModal(m)}
                onSuccess={() => setAuthModal(null)}
              />
            </Suspense>
          </div>
        </div>
      )}

    </div>
  )
}
