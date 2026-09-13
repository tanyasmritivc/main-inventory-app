'use client'

import { Suspense, useEffect, useState } from 'react'
import Link from 'next/link'
import {
  ArrowRight,
  Barcode,
  Boxes,
  Camera,
  Check,
  FileSpreadsheet,
  MapPin,
  PackageSearch,
  Search,
  Sparkles,
  Users,
  X,
} from 'lucide-react'

import { AuthForm } from '@/components/site/auth-form'

const spaces = [
  { name: 'Fastener cabinet', count: '267 items', tone: 'clay' },
  { name: 'Electronics bench', count: '84 items', tone: 'olive' },
  { name: 'Machine shop', count: '126 items', tone: 'sand' },
]

const inventory = [
  { name: 'M8 flange bolt', location: 'Fastener cabinet · B12', quantity: 48 },
  { name: '608-2RS bearing', location: 'Machine shop · A04', quantity: 16 },
  { name: 'XT60 connector', location: 'Electronics bench · C08', quantity: 24 },
]

export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false)
  const [authModal, setAuthModal] = useState<'signin' | 'signup' | null>(null)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="landing-shell">
      <div className="landing-announcement">
        <span className="landing-status-dot" />
        <span>One inventory, from workbench to warehouse.</span>
        <button type="button" onClick={() => setAuthModal('signup')}>Start free <ArrowRight size={13} /></button>
      </div>

      <nav className={`landing-nav ${scrolled ? 'is-scrolled' : ''}`} aria-label="Main navigation">
        <Link href="/" className="landing-wordmark" aria-label="FindEZ home">
          <span className="findez-mark" aria-hidden="true"><i /><i /><i /></span>
          <span>FindEZ</span>
        </Link>
        <div className="landing-nav-links">
          <a href="#product">Product</a>
          <a href="#workflow">Workflow</a>
          <Link href="/pricing">Pricing</Link>
          <Link href="/docs/api">Developers</Link>
        </div>
        <div className="landing-nav-actions">
          <button className="landing-text-button" type="button" onClick={() => setAuthModal('signin')}>Sign in</button>
          <button className="landing-solid-button compact" type="button" onClick={() => setAuthModal('signup')}>Start free</button>
        </div>
      </nav>

      <main>
        <section className="landing-hero">
          <div className="landing-hero-copy">
            <div className="landing-eyebrow"><span>Inventory intelligence</span><span>Built for real work</span></div>
            <h1>Know what you have.<br /><em>Find it when you need it.</em></h1>
            <p>Capture, organize, and retrieve every part, tool, and material across your workshop—without turning inventory into another job.</p>
            <div className="landing-hero-actions">
              <button className="landing-solid-button" type="button" onClick={() => setAuthModal('signup')}>Build your inventory <ArrowRight size={16} /></button>
              <a className="landing-outline-button" href="https://apps.apple.com/app/findez/id6746827458" target="_blank" rel="noopener noreferrer">Get the iOS app</a>
            </div>
            <div className="landing-trust-row">
              <span><Check size={14} /> Start free</span>
              <span><Check size={14} /> Import existing data</span>
              <span><Check size={14} /> Built for teams</span>
            </div>
          </div>

          <div className="landing-product-visual" aria-label="FindEZ inventory workspace preview">
            <div className="product-visual-grid" aria-hidden="true" />
            <div className="product-visual-window">
              <div className="product-visual-bar">
                <div className="visual-brand"><span className="findez-mark small"><i /><i /><i /></span> FindEZ</div>
                <div className="visual-search"><Search size={13} /> Search inventory <kbd>⌘K</kbd></div>
                <div className="visual-avatar">TV</div>
              </div>
              <div className="product-visual-body">
                <aside className="visual-sidebar">
                  <span className="is-active"><Boxes size={14} /> Inventory</span>
                  <span><Camera size={14} /> Scan & import</span>
                  <span><Sparkles size={14} /> Assist</span>
                  <span><Users size={14} /> Teams</span>
                </aside>
                <div className="visual-content">
                  <div className="visual-heading"><div><small>WORKSPACE</small><strong>Inventory</strong></div><button>+ New space</button></div>
                  <div className="visual-space-grid">
                    {spaces.map((space) => <div key={space.name} className={`visual-space ${space.tone}`}><span /><strong>{space.name}</strong><small>{space.count}</small></div>)}
                  </div>
                  <div className="visual-table">
                    <div className="visual-table-header"><span>Item</span><span>Location</span><span>On hand</span></div>
                    {inventory.map((item) => <div className="visual-table-row" key={item.name}><span><i />{item.name}</span><span>{item.location}</span><strong>{item.quantity}</strong></div>)}
                  </div>
                </div>
              </div>
            </div>
            <div className="visual-float-card visual-location"><MapPin size={15} /><span><small>Located in</small><strong>Cabinet B · Drawer 12</strong></span></div>
            <div className="visual-float-card visual-count"><PackageSearch size={15} /><span><small>Inventory ready</small><strong>477 items organized</strong></span></div>
          </div>
        </section>

        <section className="landing-section" id="product">
          <div className="landing-section-intro">
            <span className="landing-kicker">A calmer way to keep track</span>
            <h2>One clear system for everything you work with.</h2>
            <p>FindEZ gives physical inventory the same structure and searchability as your digital files.</p>
          </div>
          <div className="landing-capability-grid">
            <article className="capability-card capture-card">
              <div className="capability-copy"><span>01 · Capture</span><h3>Bring inventory in without slowing down.</h3><p>Scan a barcode, photograph a shelf, add one item, or import a spreadsheet.</p></div>
              <div className="capture-graphic" aria-hidden="true">
                <div className="capture-frame"><span className="corner tl" /><span className="corner tr" /><span className="corner bl" /><span className="corner br" /><Barcode size={76} strokeWidth={1} /><i /></div>
                <div className="capture-tools"><span><Barcode size={14} /> Barcode</span><span><Camera size={14} /> Photo</span><span><FileSpreadsheet size={14} /> Sheet</span></div>
              </div>
            </article>
            <article className="capability-card organize-card">
              <div className="capability-copy"><span>02 · Organize</span><h3>Match the way your space actually works.</h3><p>Group parts by room, cabinet, project, or team. Keep location and quantity attached.</p></div>
              <div className="organize-graphic" aria-hidden="true">
                {spaces.map((space, index) => <div key={space.name} style={{ '--card-index': index } as React.CSSProperties}><i className={space.tone} /><span><strong>{space.name}</strong><small>{space.count}</small></span><b>{String(index + 1).padStart(2, '0')}</b></div>)}
              </div>
            </article>
            <article className="capability-card find-card">
              <div className="capability-copy"><span>03 · Retrieve</span><h3>Ask naturally. Get a useful answer.</h3><p>Find parts, check stock, and understand where everything lives through one search.</p></div>
              <div className="find-graphic" aria-hidden="true">
                <div className="find-query"><Search size={15} /><span>Where are the M8 flange bolts?</span></div>
                <div className="find-answer"><Sparkles size={16} /><p><strong>Fastener cabinet</strong><br />Drawer B12 · 48 on hand</p></div>
              </div>
            </article>
          </div>
        </section>

        <section className="landing-workflow" id="workflow">
          <div className="workflow-copy">
            <span className="landing-kicker">From capture to answer</span>
            <h2>Built around the work, not around data entry.</h2>
            <p>Use the tool that fits the moment. FindEZ keeps the result consistent across mobile, web, and your team.</p>
            <Link href="/signup">Explore the workspace <ArrowRight size={15} /></Link>
          </div>
          <div className="workflow-diagram" aria-label="FindEZ workflow">
            <div className="workflow-line" />
            {[
              { icon: Camera, title: 'Capture', note: 'Photo, barcode, or import' },
              { icon: Boxes, title: 'Structure', note: 'Spaces, locations, quantities' },
              { icon: PackageSearch, title: 'Retrieve', note: 'Search, assist, and share' },
            ].map(({ icon: Icon, title, note }, index) => <div className="workflow-step" key={title}><span>{String(index + 1).padStart(2, '0')}</span><div><Icon size={20} /><strong>{title}</strong><small>{note}</small></div></div>)}
          </div>
        </section>

        <section className="landing-final-cta">
          <div className="final-cta-mark" aria-hidden="true"><span /><span /><span /><span /></div>
          <div><span className="landing-kicker">Start with what you have</span><h2>Your inventory should make work easier.</h2><p>Create a space, add a few items, and make the things around you instantly findable.</p></div>
          <button className="landing-solid-button" type="button" onClick={() => setAuthModal('signup')}>Start building <ArrowRight size={16} /></button>
        </section>
      </main>

      <footer className="landing-footer">
        <div className="landing-footer-brand"><Link href="/" className="landing-wordmark"><span className="findez-mark"><i /><i /><i /></span><span>FindEZ</span></Link><p>Inventory intelligence for workshops, labs, and teams.</p></div>
        <div className="landing-footer-links"><div><strong>Product</strong><Link href="/pricing">Pricing</Link><a href="https://apps.apple.com/app/findez/id6746827458" target="_blank" rel="noopener noreferrer">iOS app</a></div><div><strong>Resources</strong><Link href="/docs/api">API docs</Link><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div></div>
        <div className="landing-footer-bottom"><span>© {new Date().getFullYear()} AI Robots Inc.</span><span>Designed for the places where real work happens.</span></div>
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
