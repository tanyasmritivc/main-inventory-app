'use client'
import React, { useEffect, useRef, useState, useMemo } from 'react'
import Link from 'next/link'

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

// ── GRADUAL BLUR ─────────────────────────────────────────────────────────────

type GradualBlurProps = React.PropsWithChildren<{
  position?: 'top' | 'bottom' | 'left' | 'right'
  strength?: number
  height?: string
  width?: string
  divCount?: number
  exponential?: boolean
  zIndex?: number
  animated?: boolean | 'scroll'
  duration?: string
  easing?: string
  opacity?: number
  curve?: 'linear' | 'bezier' | 'ease-in' | 'ease-out' | 'ease-in-out'
  responsive?: boolean
  mobileHeight?: string
  tabletHeight?: string
  desktopHeight?: string
  mobileWidth?: string
  tabletWidth?: string
  desktopWidth?: string
  preset?: 'top' | 'bottom' | 'left' | 'right' | 'subtle' | 'intense' | 'smooth' | 'sharp' | 'header' | 'footer' | 'sidebar' | 'page-header' | 'page-footer'
  gpuOptimized?: boolean
  hoverIntensity?: number
  target?: 'parent' | 'page'
  onAnimationComplete?: () => void
  className?: string
  style?: React.CSSProperties
}>

const _GB_DEFAULT: Partial<GradualBlurProps> = {
  position: 'bottom', strength: 2, height: '6rem', divCount: 5,
  exponential: false, zIndex: 1000, animated: false, duration: '0.3s',
  easing: 'ease-out', opacity: 1, curve: 'linear', responsive: false,
  target: 'parent', className: '', style: {},
}

const _GB_PRESETS: Record<string, Partial<GradualBlurProps>> = {
  top: { position: 'top', height: '6rem' },
  bottom: { position: 'bottom', height: '6rem' },
  left: { position: 'left', height: '6rem' },
  right: { position: 'right', height: '6rem' },
  subtle: { height: '4rem', strength: 1, opacity: 0.8, divCount: 3 },
  intense: { height: '10rem', strength: 4, divCount: 8, exponential: true },
  smooth: { height: '8rem', curve: 'bezier', divCount: 10 },
  sharp: { height: '5rem', curve: 'linear', divCount: 4 },
  header: { position: 'top', height: '8rem', curve: 'ease-out' },
  footer: { position: 'bottom', height: '8rem', curve: 'ease-out' },
  sidebar: { position: 'left', height: '6rem', strength: 2.5 },
  'page-header': { position: 'top', height: '10rem', target: 'page', strength: 3 },
  'page-footer': { position: 'bottom', height: '10rem', target: 'page', strength: 3 },
}

const _GB_CURVES: Record<string, (p: number) => number> = {
  linear: p => p,
  bezier: p => p * p * (3 - 2 * p),
  'ease-in': p => p * p,
  'ease-out': p => 1 - Math.pow(1 - p, 2),
  'ease-in-out': p => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2),
}

function _gbDebounce<T extends (...a: unknown[]) => void>(fn: T, wait: number) {
  let t: ReturnType<typeof setTimeout>
  return (...a: Parameters<T>) => { clearTimeout(t); t = setTimeout(() => fn(...a), wait) }
}

function _useGBResponsiveDimension(
  responsive: boolean | undefined,
  config: Partial<GradualBlurProps>,
  key: keyof GradualBlurProps,
) {
  const [val, setVal] = useState<unknown>((config as Record<string, unknown>)[key as string])
  useEffect(() => {
    if (!responsive) return
    const calc = () => {
      const w = window.innerWidth
      const k = (key as string).charAt(0).toUpperCase() + (key as string).slice(1)
      let v: unknown = (config as Record<string, unknown>)[key as string]
      if (w <= 480 && (config as Record<string, unknown>)['mobile' + k]) v = (config as Record<string, unknown>)['mobile' + k]
      else if (w <= 768 && (config as Record<string, unknown>)['tablet' + k]) v = (config as Record<string, unknown>)['tablet' + k]
      else if (w <= 1024 && (config as Record<string, unknown>)['desktop' + k]) v = (config as Record<string, unknown>)['desktop' + k]
      setVal(v)
    }
    const deb = _gbDebounce(calc, 100)
    calc()
    window.addEventListener('resize', deb)
    return () => window.removeEventListener('resize', deb)
  }, [responsive, config, key])
  return responsive ? val : (config as Record<string, unknown>)[key as string]
}

function _useGBIntersection(ref: React.RefObject<HTMLDivElement | null>, shouldObserve = false) {
  const [isVisible, setIsVisible] = useState(!shouldObserve)
  useEffect(() => {
    if (!shouldObserve || !ref.current) return
    const observer = new IntersectionObserver(([entry]) => setIsVisible(entry.isIntersecting), { threshold: 0.1 })
    observer.observe(ref.current)
    return () => observer.disconnect()
  }, [ref, shouldObserve])
  return isVisible
}

const GradualBlurComponent: React.FC<GradualBlurProps> = (props) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const [isHovered, setIsHovered] = useState(false)

  const config = useMemo(() => {
    const preset = props.preset && _GB_PRESETS[props.preset] ? _GB_PRESETS[props.preset] : {}
    return { ..._GB_DEFAULT, ...preset, ...props } as Required<GradualBlurProps>
  }, [props])

  const responsiveHeight = _useGBResponsiveDimension(config.responsive, config, 'height') as string | undefined
  const responsiveWidth = _useGBResponsiveDimension(config.responsive, config, 'width') as string | undefined
  const isVisible = _useGBIntersection(containerRef, config.animated === 'scroll')

  const blurDivs = useMemo(() => {
    const divs: React.ReactNode[] = []
    const increment = 100 / config.divCount
    const curStr = isHovered && config.hoverIntensity ? config.strength * config.hoverIntensity : config.strength
    const curveFunc = _GB_CURVES[config.curve] ?? _GB_CURVES.linear
    for (let i = 1; i <= config.divCount; i++) {
      const progress = curveFunc(i / config.divCount)
      const blurValue = config.exponential
        ? Math.pow(2, progress * 4) * 0.0625 * curStr
        : 0.0625 * (progress * config.divCount + 1) * curStr
      const p1 = Math.round((increment * i - increment) * 10) / 10
      const p2 = Math.round(increment * i * 10) / 10
      const p3 = Math.round((increment * i + increment) * 10) / 10
      const p4 = Math.round((increment * i + increment * 2) * 10) / 10
      let gradient = `transparent ${p1}%, black ${p2}%`
      if (p3 <= 100) gradient += `, black ${p3}%`
      if (p4 <= 100) gradient += `, transparent ${p4}%`
      const direction = ({ top: 'to top', bottom: 'to bottom', left: 'to left', right: 'to right' } as Record<string, string>)[config.position] ?? 'to bottom'
      const divStyle: React.CSSProperties = {
        maskImage: `linear-gradient(${direction}, ${gradient})`,
        WebkitMaskImage: `linear-gradient(${direction}, ${gradient})`,
        backdropFilter: `blur(${blurValue.toFixed(3)}rem)`,
        opacity: config.opacity,
        transition: config.animated && config.animated !== 'scroll' ? `backdrop-filter ${config.duration} ${config.easing}` : undefined,
      }
      divs.push(<div key={i} className="absolute inset-0" style={divStyle} />)
    }
    return divs
  }, [config, isHovered])

  const containerStyle: React.CSSProperties = useMemo(() => {
    const isVertical = ['top', 'bottom'].includes(config.position)
    const isHorizontal = ['left', 'right'].includes(config.position)
    const isPageTarget = config.target === 'page'
    const base: React.CSSProperties = {
      position: isPageTarget ? 'fixed' : 'absolute',
      pointerEvents: config.hoverIntensity ? 'auto' : 'none',
      opacity: isVisible ? 1 : 0,
      transition: config.animated ? `opacity ${config.duration} ${config.easing}` : undefined,
      zIndex: isPageTarget ? config.zIndex + 100 : config.zIndex,
      ...config.style,
    }
    if (isVertical) {
      base.height = responsiveHeight; base.width = responsiveWidth ?? '100%'
      ;(base as Record<string, unknown>)[config.position] = 0
      base.left = 0; base.right = 0
    } else if (isHorizontal) {
      base.width = responsiveWidth ?? responsiveHeight; base.height = '100%'
      ;(base as Record<string, unknown>)[config.position] = 0
      base.top = 0; base.bottom = 0
    }
    return base
  }, [config, responsiveHeight, responsiveWidth, isVisible])

  useEffect(() => {
    if (isVisible && config.animated === 'scroll' && config.onAnimationComplete) {
      const t = setTimeout(() => config.onAnimationComplete?.(), parseFloat(config.duration) * 1000)
      return () => clearTimeout(t)
    }
  }, [isVisible, config])

  return (
    <div
      ref={containerRef}
      className={`gradual-blur relative isolate ${config.target === 'page' ? 'gradual-blur-page' : 'gradual-blur-parent'} ${config.className}`}
      style={containerStyle}
      onMouseEnter={config.hoverIntensity ? () => setIsHovered(true) : undefined}
      onMouseLeave={config.hoverIntensity ? () => setIsHovered(false) : undefined}
    >
      <div className="relative w-full h-full">{blurDivs}</div>
      {props.children && <div className="relative">{props.children}</div>}
    </div>
  )
}

const GradualBlurMemo = React.memo(GradualBlurComponent)
GradualBlurMemo.displayName = 'GradualBlur'

// ─────────────────────────────────────────────────────────────────────────────

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
      <section style={{
        padding: '120px 40px 100px',
        maxWidth: '1200px',
        margin: '0 auto',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden',
      }}>
        <div style={{ position: 'relative', zIndex: 2 }}>
        <div style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '6px',
          padding: '4px 12px',
          border: '1px solid #e5e7eb',
          borderRadius: '99px',
          fontSize: '12px',
          color: '#6b7280',
          marginBottom: '32px',
          letterSpacing: '-0.005em',
        }}>
          <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#22c55e', display: 'inline-block' }} />
          Powered by GPT-4o vision
        </div>

        <h1 style={{
          fontSize: 'clamp(48px, 7vw, 80px)',
          fontWeight: 600,
          letterSpacing: '-0.04em',
          lineHeight: 1.05,
          color: '#0a0a0a',
          marginBottom: '24px',
          maxWidth: '900px',
          margin: '0 auto 24px',
        }}>
          Your workshop<br />inventory assistant.
        </h1>

        <p style={{
          fontSize: '18px',
          lineHeight: 1.6,
          color: '#6b7280',
          maxWidth: '520px',
          margin: '0 auto 40px',
          letterSpacing: '-0.01em',
          fontWeight: 400,
        }}>
          Scan anything. Ask anything. Never buy something you already own.
          Works on iPhone and web, always in sync.
        </p>

        <div style={{ display: 'flex', gap: '10px', justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link
            href="/signup"
            style={{
              padding: '12px 28px',
              fontSize: '15px',
              fontWeight: 500,
              color: '#fff',
              background: '#0a0a0a',
              textDecoration: 'none',
              borderRadius: '8px',
              letterSpacing: '-0.01em',
              transition: 'opacity 0.15s',
              display: 'inline-block',
            }}
            onMouseEnter={e => (e.currentTarget.style.opacity = '0.8')}
            onMouseLeave={e => (e.currentTarget.style.opacity = '1')}
          >
            Get started free
          </Link>
          <Link
            href="/signin"
            style={{
              padding: '12px 24px',
              fontSize: '15px',
              fontWeight: 400,
              color: '#0a0a0a',
              background: 'transparent',
              border: '1px solid #e5e7eb',
              textDecoration: 'none',
              borderRadius: '8px',
              letterSpacing: '-0.01em',
              transition: 'border-color 0.15s, background 0.15s',
              display: 'inline-block',
            }}
            onMouseEnter={e => { e.currentTarget.style.background = '#f9fafb'; e.currentTarget.style.borderColor = '#d1d5db' }}
            onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.borderColor = '#e5e7eb' }}
          >
            Sign in
          </Link>
        </div>

        <p style={{ fontSize: '13px', color: '#9ca3af', marginTop: '16px', letterSpacing: '-0.005em' }}>
          Free to start · No credit card required · iOS + Web
        </p>
        </div>
        <GradualBlurMemo position="bottom" height="80px" strength={2} zIndex={1} />
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
