'use client'

import Image from 'next/image'
import Link from 'next/link'
import { Suspense, useEffect, useState } from 'react'
import {
  ArrowDown,
  ArrowRight,
  Barcode,
  Boxes,
  Camera,
  Check,
  FileSpreadsheet,
  MapPin,
  Search,
  Sparkles,
  X,
} from 'lucide-react'

import { AuthForm } from '@/components/site/auth-form'

const detections = [
  { label: 'Bearing', className: 'detection bearing-one' },
  { label: 'Bearing', className: 'detection bearing-two' },
  { label: 'Bracket', className: 'detection bracket' },
  { label: 'Connector', className: 'detection connector' },
]

const recognizedItems = [
  { name: 'Hex bolts', quantity: 7 },
  { name: 'Washers & nuts', quantity: 9 },
  { name: 'Ball bearings', quantity: 2 },
  { name: 'Wire leads', quantity: 2 },
]

export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false)
  const [authModal, setAuthModal] = useState<'signin' | 'signup' | null>(null)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="simple-landing">
      <nav className={`simple-nav ${scrolled ? 'is-scrolled' : ''}`} aria-label="Main navigation">
        <Link href="/" className="landing-wordmark" aria-label="FindEZ home">
          <span className="findez-mark" aria-hidden="true"><i /><i /><i /></span>
          <span>FindEZ</span>
        </Link>
        <div className="simple-nav-links">
          <a href="#product">Product</a>
          <a href="#how-it-works">How it works</a>
          <Link href="/docs/api">Developers</Link>
        </div>
        <div className="simple-nav-actions">
          <button type="button" onClick={() => setAuthModal('signin')}>Sign in</button>
          <button className="simple-primary compact" type="button" onClick={() => setAuthModal('signup')}>Start free</button>
        </div>
      </nav>

      <main>
        <section className="simple-hero" id="product">
          <div className="simple-hero-copy">
            <h1>Know what you have.<br /><span><em>Find it</em> when you need it.</span></h1>
            <p>Photograph what&apos;s around you. FindEZ identifies it, organizes it, and remembers where it lives.</p>
            <div className="simple-hero-actions">
              <button className="simple-primary" type="button" onClick={() => setAuthModal('signup')}>Start free <ArrowRight size={15} /></button>
              <a href="#how-it-works">See how it works <ArrowDown size={14} /></a>
            </div>
          </div>

          <div className="ai-demo" aria-label="FindEZ identifies physical objects from a photograph and adds them to inventory">
            <header><span><Camera size={14} /> Photo scan</span><b>20 objects found</b></header>
            <div className="ai-demo-content">
              <div className="ai-photo">
                <Image src="/images/findez-parts-bin.jpg" alt="A workshop bin containing bolts, washers, bearings, wires, and a connector" fill priority sizes="(max-width: 980px) 100vw, 55vw" />
                <div className="scan-sweep" />
                {detections.map((item) => <span className={item.className} key={`${item.label}-${item.className}`}><i>{item.label}</i></span>)}
                <div className="ai-photo-status"><Sparkles size={13} /> FindEZ is identifying this bin</div>
              </div>
              <aside className="ai-results">
                <div className="ai-results-heading"><span>Recognized inventory</span><Check size={14} /></div>
                <div className="ai-results-list">
                  {recognizedItems.map((item) => <div key={item.name}><span><i />{item.name}</span><strong>{item.quantity}</strong></div>)}
                </div>
                <div className="ai-results-location"><MapPin size={14} /><span><small>Saved to</small><strong>Workshop · Green parts bin</strong></span></div>
              </aside>
            </div>
          </div>
        </section>

        <section className="simple-process" id="how-it-works">
          <header><h2>From a photo to organized inventory.</h2><p>Use a photo for a whole space. Barcode and spreadsheet import are there when you need them.</p></header>
          <div className="simple-process-steps">
            <article><span>1</span><Camera size={20} /><div><strong>Show FindEZ</strong><p>Photograph a bin, shelf, room, or collection.</p></div></article>
            <article><span>2</span><Sparkles size={20} /><div><strong>AI understands it</strong><p>Objects, labels, and useful details become inventory records.</p></div></article>
            <article><span>3</span><Search size={20} /><div><strong>Find anything later</strong><p>Search by name or ask where something is.</p></div></article>
          </div>
          <div className="simple-import-methods"><span><Barcode size={14} /> Barcode</span><span><Camera size={14} /> Photo</span><span><FileSpreadsheet size={14} /> Spreadsheet</span><span><Boxes size={14} /> Manual entry</span></div>
        </section>

        <section className="ask-demo">
          <div className="ask-demo-copy"><h2>Just ask.</h2><p>FindEZ remembers the physical things you keep and where you put them.</p></div>
          <div className="ask-conversation">
            <div className="ask-question"><Search size={15} /><span>Where are my 608 bearings?</span></div>
            <div className="ask-answer"><span><Sparkles size={15} /></span><p>You have <strong>2 ball bearings</strong> in <strong>Workshop · Green parts bin</strong>.</p></div>
          </div>
        </section>

        <section className="simple-cta">
          <div><h2>Remember everything you keep.</h2><p>Start with one photo.</p></div>
          <button className="simple-primary" type="button" onClick={() => setAuthModal('signup')}>Start free <ArrowRight size={15} /></button>
        </section>
      </main>

      <footer className="simple-footer">
        <Link href="/" className="landing-wordmark"><span className="findez-mark"><i /><i /><i /></span><span>FindEZ</span></Link>
        <span>© {new Date().getFullYear()} AI Robots Inc.</span>
        <div><Link href="/docs/api">Developers</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div>
      </footer>

      {authModal && (
        <div className="landing-auth-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAuthModal(null) }}>
          <div className="landing-auth-modal">
            <button className="landing-auth-close" type="button" aria-label="Close" onClick={() => setAuthModal(null)}><X size={17} /></button>
            <Suspense fallback={null}><AuthForm mode={authModal} onToggleMode={setAuthModal} onSuccess={() => setAuthModal(null)} /></Suspense>
          </div>
        </div>
      )}
    </div>
  )
}
