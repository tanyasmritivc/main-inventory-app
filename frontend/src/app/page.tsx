'use client'
import React, { useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import GradualBlur from '@/components/ui/GradualBlur'
import FloatingLines from '@/components/ui/FloatingLines'
import SpecularButton from '@/components/ui/SpecularButton'

function useCounter(end: number, duration: number = 2000, start: boolean = false) {
  const [count, setCount] = useState(0)
  useEffect(() => {
    if (!start) return
    let startTime = 0
    const step = (timestamp: number) => {
      if (!startTime) startTime = timestamp
      const progress = Math.min((timestamp - startTime) / duration, 1)
      setCount(Math.floor(progress * end))
      if (progress < 1) requestAnimationFrame(step)
    }
    requestAnimationFrame(step)
  }, [end, duration, start])
  return count
}

function useInView(threshold = 0.1) {
  const ref = useRef<HTMLDivElement>(null)
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setInView(true) },
      { threshold }
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [threshold])
  return { ref, inView }
}

const features = [
  {
    n: '01',
    title: 'Scan or photograph',
    desc: 'Point your camera at any barcode or receipt. AI vision fills in every field automatically — name, brand, quantity, category, and more.',
  },
  {
    n: '02',
    title: 'Ask in plain language',
    desc: '"Do I have a 10mm socket wrench?" Get an answer instantly. No searching. No scrolling. No guessing.',
  },
  {
    n: '03',
    title: 'Import spreadsheets',
    desc: 'Drag in any .xlsx or .csv file. AI automatically maps your columns and imports everything in one pass.',
  },
  {
    n: '04',
    title: 'Share with a code',
    desc: 'Generate a six-character invite code. Teammates join from iPhone or web with view or edit permissions.',
  },
  {
    n: '05',
    title: 'Low stock alerts',
    desc: 'Set thresholds for individual items or entire categories. FindEZ lets you know before supplies run out.',
  },
  {
    n: '06',
    title: 'iOS + Web sync',
    desc: 'Native iPhone app and full web experience. Every scan, edit, and inventory update stays synchronized instantly.',
  },
]

const testimonials = [
  {
    quote: 'I stopped buying duplicate tools. Now I ask FindEZ before I go to the hardware store. Takes two seconds.',
    name: 'Marcus T.',
    role: 'Homeowner',
  },
  {
    quote: 'We track 400+ robot parts across three team spaces. The spreadsheet import mapped every column perfectly.',
    name: 'Priya K.',
    role: 'FRC Team Lead',
  },
  {
    quote: 'Photographed an entire parts shelf. The AI got every item right. Genuinely did not expect it to work that well.',
    name: 'James R.',
    role: 'Small business owner',
  },
]

export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false)
  const [hoveredFeature, setHoveredFeature] = useState<string | null>(null)
  const statsRef = useInView(0.3)
  const items = useCounter(10000, 2000, statsRef.inView)
  const teams = useCounter(500, 2000, statsRef.inView)
  const time = useCounter(2, 1500, statsRef.inView)

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

      {/* ── DIVIDER ── */}
      <div style={{ borderTop: '1px solid #e5e7eb', maxWidth: '1200px', margin: '0 auto' }} />

      {/* ── STATS ── */}
      <section ref={statsRef.ref} style={{
        padding: '80px 40px',
        maxWidth: '1200px',
        margin: '0 auto',
        display: 'grid',
        gridTemplateColumns: 'repeat(3, 1fr)',
        gap: '1px',
        background: '#e5e7eb',
        border: '1px solid #e5e7eb',
        borderRadius: '12px',
      }}>
        {[
          { value: items, suffix: '+', label: 'Items tracked' },
          { value: teams, suffix: '+', label: 'Teams using FindEZ' },
          { value: time, suffix: ' min', label: 'Setup time' },
        ].map((s, i) => (
          <div key={i} style={{
            background: '#fff',
            padding: '40px 48px',
            textAlign: 'center',
          }}>
            <div style={{
              fontSize: '48px',
              fontWeight: 600,
              letterSpacing: '-0.04em',
              color: '#0a0a0a',
              lineHeight: 1,
              marginBottom: '8px',
            }}>
              {s.value.toLocaleString()}{s.suffix}
            </div>
            <div style={{ fontSize: '14px', color: '#9ca3af', letterSpacing: '-0.01em' }}>
              {s.label}
            </div>
          </div>
        ))}
      </section>

      {/* ── CAPABILITIES ── */}
      <section style={{ padding: '100px 40px', maxWidth: '1200px', margin: '0 auto' }}>
        <div style={{ marginBottom: '64px' }}>
          <div style={{
            fontSize: '11px',
            fontWeight: 500,
            letterSpacing: '0.1em',
            textTransform: 'uppercase' as const,
            color: '#9ca3af',
            marginBottom: '16px',
          }}>
            Capabilities
          </div>
          <h2 style={{
            fontSize: 'clamp(32px, 4vw, 48px)',
            fontWeight: 600,
            letterSpacing: '-0.035em',
            lineHeight: 1.1,
            color: '#0a0a0a',
            maxWidth: '600px',
            marginBottom: '16px',
          }}>
            Everything your inventory needs.
          </h2>
          <p style={{
            fontSize: '16px',
            color: '#6b7280',
            lineHeight: 1.6,
            maxWidth: '480px',
            letterSpacing: '-0.01em',
          }}>
            Built for homes, workshops, robotics teams, and small businesses.
          </p>
        </div>

        {/* Feature grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: '0',
          border: '1px solid #e5e7eb',
          borderRadius: '12px',
          overflow: 'hidden',
        }}>
          {features.map((f, i) => (
            <div
              key={f.n}
              style={{
                padding: '40px 48px',
                borderRight: i % 2 === 0 ? '1px solid #e5e7eb' : 'none',
                borderBottom: i < 4 ? '1px solid #e5e7eb' : 'none',
                background: hoveredFeature === f.n ? '#f9fafb' : '#fff',
                transition: 'background 0.15s',
                cursor: 'default',
              }}
              onMouseEnter={() => setHoveredFeature(f.n)}
              onMouseLeave={() => setHoveredFeature(null)}
            >
              <div style={{
                fontSize: '12px',
                fontWeight: 500,
                fontFamily: "'SF Mono', 'Fira Mono', 'Cascadia Code', monospace",
                color: '#9ca3af',
                letterSpacing: '0.04em',
                marginBottom: '16px',
              }}>
                {f.n}
              </div>
              <div style={{
                fontSize: '18px',
                fontWeight: 500,
                letterSpacing: '-0.025em',
                color: '#0a0a0a',
                marginBottom: '10px',
                lineHeight: 1.3,
              }}>
                {f.title}
              </div>
              <div style={{
                fontSize: '15px',
                color: '#6b7280',
                lineHeight: 1.6,
                letterSpacing: '-0.01em',
              }}>
                {f.desc}
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── DIVIDER ── */}
      <div style={{ borderTop: '1px solid #e5e7eb', maxWidth: '1200px', margin: '0 auto' }} />

      {/* ── TESTIMONIALS ── */}
      <section style={{ padding: '100px 40px', maxWidth: '1200px', margin: '0 auto' }}>
        <div style={{
          fontSize: '11px',
          fontWeight: 500,
          letterSpacing: '0.1em',
          textTransform: 'uppercase' as const,
          color: '#9ca3af',
          marginBottom: '48px',
        }}>
          What people say
        </div>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(3, 1fr)',
          gap: '24px',
        }}>
          {testimonials.map((t, i) => (
            <div key={i} style={{
              padding: '32px',
              border: '1px solid #e5e7eb',
              borderRadius: '10px',
              background: '#fff',
              transition: 'border-color 0.15s, box-shadow 0.15s',
            }}
              onMouseEnter={e => {
                e.currentTarget.style.borderColor = '#d1d5db'
                e.currentTarget.style.boxShadow = '0 4px 24px rgba(0,0,0,0.06)'
              }}
              onMouseLeave={e => {
                e.currentTarget.style.borderColor = '#e5e7eb'
                e.currentTarget.style.boxShadow = 'none'
              }}
            >
              <p style={{
                fontSize: '15px',
                lineHeight: 1.65,
                color: '#374151',
                letterSpacing: '-0.01em',
                marginBottom: '20px',
                fontStyle: 'italic',
              }}>
                &ldquo;{t.quote}&rdquo;
              </p>
              <div style={{ borderTop: '1px solid #f3f4f6', paddingTop: '16px' }}>
                <div style={{ fontSize: '14px', fontWeight: 500, color: '#0a0a0a', letterSpacing: '-0.01em' }}>
                  {t.name}
                </div>
                <div style={{ fontSize: '13px', color: '#9ca3af', marginTop: '2px' }}>
                  {t.role}
                </div>
              </div>
            </div>
          ))}
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
