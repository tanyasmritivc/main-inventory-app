'use client'
import React, { useEffect, useState } from 'react'
import Link from 'next/link'
import GradualBlur from '@/components/ui/GradualBlur'
import FloatingLines from '@/components/ui/FloatingLines'
import SpecularButton from '@/components/ui/SpecularButton'
import MagicBento from '@/components/ui/MagicBento'


export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false)

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
        background: '#0a0a0a',
        color: '#fff',
        textAlign: 'center',
        padding: '10px 24px',
        fontSize: '13px',
        letterSpacing: '-0.01em',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '8px',
      }}>
        <span style={{ color: '#9ca3af' }}>FindEZ AI is now available on iOS.</span>
        <Link href="/signup" style={{ color: '#fff', textDecoration: 'none', fontWeight: 500, borderBottom: '1px solid rgba(255,255,255,0.3)' }}>
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
          <Link
            href="/signin"
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
            Sign in
          </Link>
          <Link
            href="/signup"
            style={{
              padding: '7px 16px',
              fontSize: '14px',
              fontWeight: 500,
              color: '#fff',
              background: '#0a0a0a',
              textDecoration: 'none',
              borderRadius: '6px',
              letterSpacing: '-0.01em',
              transition: 'opacity 0.15s',
              marginLeft: '4px',
            }}
            onMouseEnter={e => (e.currentTarget.style.opacity = '0.8')}
            onMouseLeave={e => (e.currentTarget.style.opacity = '1')}
          >
            Get started
          </Link>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section style={{ padding: '40px 40px 0', background: '#fff' }}>
        {/* Contained hero box like Scale AI */}
        <div style={{
          position: 'relative',
          borderRadius: '16px',
          overflow: 'hidden',
          minHeight: '560px',
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
              <div style={{ transform: 'scale(1.8)', transformOrigin: 'center center' }}>
                <SpecularButton
                  size="lg"
                  radius={28}
                  tint="#ffffff"
                  tintOpacity={0.06}
                  blur={0}
                  textColor="#ffffff"
                  lineColor="#ffffff"
                  baseColor="#525252"
                  intensity={1.2}
                  shineSize={10}
                  shineFade={40}
                  thickness={1}
                  speed={0.35}
                  followMouse={true}
                  proximity={250}
                  autoAnimate={false}
                  onClick={() => window.location.href = '/signup'}
                >
                  Get Started
                </SpecularButton>
              </div>
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

      {/* ── CAPABILITIES ── */}
      <section style={{ background: '#fff', padding: '80px 0' }}>
        <div style={{ maxWidth: '900px', margin: '0 auto', padding: '0 24px' }}>
          <p style={{ fontSize: '11px', fontWeight: 500, letterSpacing: '0.12em',
            textTransform: 'uppercase', color: 'rgba(0,0,0,0.4)', marginBottom: '16px' }}>
            Capabilities
          </p>
          <h2 style={{ fontSize: '2.4rem', fontWeight: 700, color: '#000',
            marginBottom: '48px', lineHeight: 1.15 }}>
            Everything your inventory needs.
          </h2>
          <MagicBento
            textAutoHide={false}
            enableStars={true}
            enableSpotlight={true}
            enableBorderGlow={true}
            enableTilt={false}
            enableMagnetism={false}
            clickEffect={true}
            spotlightRadius={400}
            particleCount={12}
            glowColor="132, 0, 255"
            disableAnimations={false}
          />
        </div>
      </section>

      {/* ── CTA ── */}
      <section style={{
        background: '#0a0a0a',
        padding: '100px 40px',
        textAlign: 'center',
      }}>
        <h2 style={{
          fontSize: 'clamp(36px, 5vw, 64px)',
          fontWeight: 600,
          letterSpacing: '-0.04em',
          lineHeight: 1.05,
          color: '#fff',
          marginBottom: '16px',
          maxWidth: '800px',
          margin: '0 auto 16px',
        }}>
          Stop losing track of things.
        </h2>
        <p style={{
          fontSize: '16px',
          color: 'rgba(255,255,255,0.5)',
          marginBottom: '36px',
          letterSpacing: '-0.01em',
        }}>
          Free to start. Works in your browser and on iPhone.
        </p>
        <Link
          href="/signup"
          style={{
            display: 'inline-block',
            padding: '13px 32px',
            fontSize: '15px',
            fontWeight: 500,
            color: '#0a0a0a',
            background: '#fff',
            textDecoration: 'none',
            borderRadius: '8px',
            letterSpacing: '-0.01em',
            transition: 'opacity 0.15s',
          }}
          onMouseEnter={e => (e.currentTarget.style.opacity = '0.85')}
          onMouseLeave={e => (e.currentTarget.style.opacity = '1')}
        >
          Create your inventory →
        </Link>
      </section>

      {/* ── FOOTER ── */}
      <footer style={{
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

    </div>
  )
}
