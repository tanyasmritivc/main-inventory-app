'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';

export default function LandingPage() {
  const [scrolled, setScrolled] = useState(false);
  const [typed, setTyped] = useState('');

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    const fullText = 'Add 24 AA batteries to Kitchen';
    let i = 0;
    const timer = setInterval(() => {
      i++;
      if (i <= fullText.length) {
        setTyped(fullText.slice(0, i));
      } else {
        clearInterval(timer);
      }
    }, 60);
    return () => clearInterval(timer);
  }, []);

  const features = [
    { n: '01', title: 'Scan or photograph', desc: 'Point your camera at any barcode or receipt. GPT-4o vision fills in every field — name, brand, quantity, category.' },
    { n: '02', title: 'Ask in plain language', desc: '"Do I have a 10mm socket wrench?" gets a real answer instantly. No searching, no scrolling, no guessing.' },
    { n: '03', title: 'Import spreadsheets', desc: 'Drag in any .xlsx or .csv. AI maps columns automatically and bulk-imports everything in one pass.' },
    { n: '04', title: 'Share with a code', desc: 'Generate a 6-character code. Anyone on iOS or web joins your space with view or edit access instantly.' },
    { n: '05', title: 'Low stock alerts', desc: 'Set thresholds per item or category. FindEZ tells you what\'s running out before you actually run out.' },
    { n: '06', title: 'iOS + web in sync', desc: 'Full native iPhone app and this web app. Every scan, edit, and share syncs instantly across both.' },
  ];

  const quotes = [
    { q: '"I stopped buying duplicate tools. Now I just ask FindEZ before I go to Home Depot. Takes two seconds."', name: 'Marcus T.', role: 'Homeowner, Austin TX' },
    { q: '"We track 400+ robot parts across three team spaces. The spreadsheet import mapped every column perfectly."', name: 'Priya K.', role: 'FRC Team Lead, Bay Area' },
    { q: '"Photographed an entire parts shelf. The AI got every item right. Genuinely didn\'t expect it to work that well."', name: 'James R.', role: 'Small business owner' },
  ];

  return (
    <div style={{ background: '#000', color: '#f5f5f7', fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif", WebkitFontSmoothing: 'antialiased', minHeight: '100vh' }}>

      {/* NAV */}
      <nav style={{
        position: 'sticky', top: 0, zIndex: 100,
        height: '48px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 28px',
        background: scrolled ? 'rgba(0,0,0,0.82)' : 'transparent',
        backdropFilter: scrolled ? 'blur(20px) saturate(180%)' : 'none',
        borderBottom: scrolled ? '1px solid #1c1c1e' : '1px solid transparent',
        transition: 'all 0.3s ease',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '7px', fontSize: '15px', fontWeight: 590, letterSpacing: '-0.022em', color: '#fff' }}>
          <div style={{ width: '20px', height: '20px', borderRadius: '5px', background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <svg width="11" height="11" viewBox="0 0 11 11" fill="none"><path d="M1.5 9L5.5 2L9.5 9" stroke="#000" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/><path d="M3 6.8h5" stroke="#000" strokeWidth="1.3" strokeLinecap="round"/></svg>
          </div>
          FindEZ
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '2px' }}>
          <a href="#features" style={{ padding: '5px 12px', fontSize: '13px', fontWeight: 400, letterSpacing: '-0.008em', color: '#a1a1a6', textDecoration: 'none' }}>Product</a>
          <a href="#pricing" style={{ padding: '5px 12px', fontSize: '13px', fontWeight: 400, letterSpacing: '-0.008em', color: '#a1a1a6', textDecoration: 'none' }}>Pricing</a>
          <a href="https://apps.apple.com/app/findez/id6746827458" target="_blank" rel="noopener noreferrer" style={{ padding: '5px 12px', fontSize: '13px', fontWeight: 400, letterSpacing: '-0.008em', color: '#a1a1a6', textDecoration: 'none' }}>iOS App</a>
          <Link href="/signin" style={{ padding: '6px 14px', borderRadius: '6px', fontSize: '13px', fontWeight: 400, letterSpacing: '-0.012em', border: '1px solid #2c2c2e', color: '#f5f5f7', textDecoration: 'none', marginRight: '6px' }}>Sign in</Link>
          <Link href="/signup" style={{ padding: '6px 14px', borderRadius: '6px', fontSize: '13px', fontWeight: 510, letterSpacing: '-0.012em', background: '#fff', color: '#000', textDecoration: 'none' }}>Get started</Link>
        </div>
      </nav>

      {/* HERO */}
      <section style={{ padding: '88px 28px 56px', textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        {/* Grid bg */}
        <div style={{ position: 'absolute', inset: 0, backgroundImage: 'linear-gradient(#1c1c1e 1px,transparent 1px),linear-gradient(90deg,#1c1c1e 1px,transparent 1px)', backgroundSize: '44px 44px', animation: 'gridPulse 7s ease-in-out infinite', pointerEvents: 'none' }} />
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '200px', background: 'linear-gradient(transparent,#000)', pointerEvents: 'none' }} />

        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 11px', borderRadius: '99px', border: '1px solid #2c2c2e', background: '#0a0a0a', fontSize: '11px', fontWeight: 500, letterSpacing: '-0.005em', color: '#a1a1a6', marginBottom: '22px', position: 'relative', zIndex: 1, animation: 'fadeUp 0.45s ease both' }}>
          <span style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#32d74b', animation: 'pulseDot 2.2s ease infinite', display: 'inline-block' }} />
          Powered by GPT-4o vision
        </div>

        <h1 style={{ fontSize: '56px', fontWeight: 700, letterSpacing: '-0.045em', lineHeight: 1.01, color: '#fff', marginBottom: '14px', position: 'relative', zIndex: 1, animation: 'fadeUp 0.45s 0.06s ease both' }}>
          The AI that remembers<br />
          <span style={{ color: '#6e6e73', fontWeight: 300 }}>everything you own.</span>
        </h1>

        <p style={{ fontSize: '16px', fontWeight: 400, letterSpacing: '-0.018em', lineHeight: 1.5, color: '#a1a1a6', maxWidth: '430px', margin: '0 auto 32px', position: 'relative', zIndex: 1, animation: 'fadeUp 0.45s 0.12s ease both' }}>
          Scan anything. Ask anything. Never buy something you already own. iOS and web, always in sync.
        </p>

        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', position: 'relative', zIndex: 1, animation: 'fadeUp 0.45s 0.18s ease both' }}>
          <Link href="/signup" style={{ padding: '11px 24px', borderRadius: '8px', fontSize: '15px', fontWeight: 510, letterSpacing: '-0.02em', background: '#fff', color: '#000', textDecoration: 'none' }}>Get started free</Link>
          <Link href="/signin" style={{ padding: '11px 20px', borderRadius: '8px', fontSize: '15px', fontWeight: 400, letterSpacing: '-0.02em', background: 'transparent', border: '1px solid #2c2c2e', color: '#f5f5f7', textDecoration: 'none' }}>Sign in</Link>
        </div>
        <p style={{ fontSize: '11px', fontWeight: 400, color: '#6e6e73', marginTop: '14px', letterSpacing: '-0.005em', position: 'relative', zIndex: 1, animation: 'fadeIn 0.5s 0.3s ease both' }}>Free · No credit card · iOS + Web</p>
      </section>

      {/* TERMINAL STRIP */}
      <div style={{ padding: '0 28px 56px', animation: 'fadeUp 0.5s 0.22s ease both' }}>
        <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: '12px', overflow: 'hidden' }}>
          {/* terminal titlebar */}
          <div style={{ background: '#111113', borderBottom: '1px solid #1c1c1e', height: '36px', display: 'flex', alignItems: 'center', padding: '0 12px', gap: '6px' }}>
            {[['#ff5f57',''], ['#ffbd2e',''], ['#28c840','']].map(([c], i) => <div key={i} style={{ width: '10px', height: '10px', borderRadius: '50%', background: c }} />)}
            <span style={{ marginLeft: '8px', fontSize: '11px', fontWeight: 400, letterSpacing: '-0.005em', color: '#6e6e73' }}>FindEZ — AI inventory assistant</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 188px' }}>
            {/* left: chat */}
            <div style={{ padding: '16px 18px', borderRight: '1px solid #1c1c1e', position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', left: 0, right: 0, height: '1px', background: 'rgba(255,255,255,0.04)', animation: 'scanline 4s linear infinite' }} />
              {[
                { k: 'you', v: 'Do I own any HDMI cables?', active: true },
                { k: 'ai', v: 'Yes — 4× HDMI 2.0 in Office, 1× HDMI 2.1 in Garage.', response: true },
                { k: 'you', v: "What's running low?", active: true },
                { k: 'ai', v: '3 items below threshold: AA Batteries (2), Isopropyl 99% (1 bottle), M3 screws (12).', response: true },
              ].map((line, i) => (
                <div key={i} style={{ fontSize: '12px', lineHeight: 1.75, fontFamily: "'SF Mono', ui-monospace, 'Cascadia Code', monospace", display: 'flex', gap: '10px', marginBottom: i < 3 ? '5px' : '10px' }}>
                  <span style={{ fontSize: '11px', color: line.k === 'ai' ? 'rgba(255,255,255,0.55)' : '#6e6e73', minWidth: '26px' }}>{line.k}</span>
                  <span style={{ color: line.response ? 'rgba(255,255,255,0.65)' : line.active ? '#f5f5f7' : '#a1a1a6' }}>{line.v}</span>
                </div>
              ))}
              <div style={{ fontSize: '12px', lineHeight: 1.75, fontFamily: "'SF Mono', ui-monospace, monospace", display: 'flex', gap: '10px' }}>
                <span style={{ fontSize: '11px', color: '#6e6e73', minWidth: '26px' }}>you</span>
                <span style={{ color: '#6e6e73' }}>{typed}<span style={{ display: 'inline-block', width: '6px', height: '12px', background: '#f5f5f7', animation: 'blink 1.1s step-end infinite', verticalAlign: 'text-bottom', marginLeft: '1px' }} /></span>
              </div>
            </div>
            {/* right: stats */}
            <div style={{ padding: '14px 12px', display: 'flex', flexDirection: 'column', gap: '7px' }}>
              {[
                { label: 'Items', val: '147', sub: '↑ 12 this week', fill: '70%', warn: false },
                { label: 'Spaces', val: '6', sub: '3 shared', fill: '42%', warn: false },
                { label: 'Attention', val: '3', sub: 'Low stock', fill: '18%', warn: true },
              ].map(s => (
                <div key={s.label} style={{ background: '#111113', border: '1px solid #1c1c1e', borderRadius: '8px', padding: '10px 12px' }}>
                  <div style={{ fontSize: '10px', fontWeight: 400, letterSpacing: '0.02em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: '3px' }}>{s.label}</div>
                  <div style={{ fontSize: '19px', fontWeight: 660, letterSpacing: '-0.04em', color: s.warn ? '#ffd60a' : '#fff', lineHeight: 1 }}>{s.val}</div>
                  <div style={{ fontSize: '10px', color: '#6e6e73', marginTop: '3px' }}>{s.sub}</div>
                  <div style={{ height: '2px', background: '#2c2c2e', borderRadius: '1px', marginTop: '7px', overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: s.fill, borderRadius: '1px', background: s.warn ? 'rgba(255,214,10,0.35)' : '#3a3a3c' }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* FEATURES */}
      <section id="features" style={{ padding: '64px 28px', borderTop: '1px solid #1c1c1e' }}>
        <div style={{ fontSize: '11px', fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: '6px' }}>Capabilities</div>
        <h2 style={{ fontSize: '34px', fontWeight: 700, letterSpacing: '-0.038em', lineHeight: 1.08, color: '#fff', marginBottom: '4px' }}>Everything your inventory needs.</h2>
        <p style={{ fontSize: '16px', fontWeight: 300, letterSpacing: '-0.02em', color: '#a1a1a6', marginBottom: '36px' }}>Built for homes, workshops, robotics teams, and small businesses.</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1px', background: '#1c1c1e', border: '1px solid #1c1c1e', borderRadius: '12px', overflow: 'hidden' }}>
          {features.map(f => (
            <div key={f.n} style={{ background: '#000', padding: '26px 22px', transition: 'background 0.18s', cursor: 'default' }}
              onMouseEnter={e => (e.currentTarget.style.background = '#0a0a0a')}
              onMouseLeave={e => (e.currentTarget.style.background = '#000')}>
              <div style={{ fontSize: '11px', fontWeight: 500, fontFamily: "'SF Mono', ui-monospace, monospace", color: '#6e6e73', letterSpacing: '0.03em', marginBottom: '11px' }}>{f.n}</div>
              <div style={{ fontSize: '14px', fontWeight: 590, letterSpacing: '-0.02em', color: '#fff', marginBottom: '5px' }}>{f.title}</div>
              <div style={{ fontSize: '12px', fontWeight: 400, letterSpacing: '-0.01em', lineHeight: 1.58, color: '#a1a1a6' }}>{f.desc}</div>
            </div>
          ))}
        </div>
      </section>

      {/* PROOF */}
      <section style={{ padding: '48px 28px', borderTop: '1px solid #1c1c1e' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
          {quotes.map(q => (
            <div key={q.name} style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: '10px', padding: '18px 18px' }}>
              <p style={{ fontSize: '12px', fontWeight: 400, letterSpacing: '-0.01em', lineHeight: 1.62, color: '#a1a1a6', marginBottom: '12px' }}>{q.q}</p>
              <div style={{ height: '1px', background: '#1c1c1e', marginBottom: '10px' }} />
              <div style={{ fontSize: '12px', fontWeight: 590, letterSpacing: '-0.015em', color: '#f5f5f7' }}>{q.name}</div>
              <div style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '-0.008em', color: '#6e6e73', marginTop: '2px' }}>{q.role}</div>
            </div>
          ))}
        </div>
      </section>

      {/* DASHBOARD PREVIEW */}
      <section style={{ padding: '0 28px', borderTop: '1px solid #1c1c1e' }}>
        <div style={{ padding: '48px 0 24px' }}>
          <div style={{ fontSize: '11px', fontWeight: 510, letterSpacing: '0.07em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: '6px' }}>The app</div>
          <h2 style={{ fontSize: '26px', fontWeight: 700, letterSpacing: '-0.038em', color: '#fff' }}>Clean. Fast. Yours.</h2>
        </div>
        <div style={{ background: '#0a0a0a', border: '1px solid #1c1c1e', borderRadius: '14px', overflow: 'hidden', marginBottom: '64px' }}>
          {/* browser chrome */}
          <div style={{ background: '#111113', borderBottom: '1px solid #1c1c1e', height: '38px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 14px' }}>
            <div style={{ display: 'flex', gap: '6px' }}>
              {['#ff5f57','#ffbd2e','#28c840'].map((c,i) => <div key={i} style={{ width: '10px', height: '10px', borderRadius: '50%', background: c }} />)}
            </div>
            <span style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '-0.008em', color: '#6e6e73' }}>findez.ai — Home</span>
            <div style={{ width: '52px' }} />
          </div>
          <div style={{ display: 'flex', height: '320px' }}>
            {/* sidebar */}
            <div style={{ width: '160px', borderRight: '1px solid #1c1c1e', background: '#0a0a0a', padding: '12px 0', flexShrink: 0, display: 'flex', flexDirection: 'column' }}>
              <div style={{ padding: '2px 12px 12px', fontSize: '13px', fontWeight: 660, letterSpacing: '-0.03em', color: '#fff', borderBottom: '1px solid #1c1c1e', marginBottom: '4px' }}>FindEZ</div>
              <div style={{ padding: '0 5px', flex: 1 }}>
                {[['Home', true], ['My Spaces', false], ['Collections', false], ['Documents', false], ['Settings', false]].map(([label, active]) => (
                  <div key={label as string} style={{ display: 'flex', alignItems: 'center', gap: '7px', padding: '6px 9px', borderRadius: '6px', fontSize: '11px', fontWeight: active ? 510 : 400, letterSpacing: '-0.01em', color: active ? '#fff' : '#6e6e73', background: active ? '#1c1c1e' : 'transparent', marginBottom: '2px' }}>
                    {label as string}
                  </div>
                ))}
              </div>
              <div style={{ padding: '8px 12px 0', borderTop: '1px solid #1c1c1e', fontSize: '10px', color: '#6e6e73' }}>tanya28c@gmail.com</div>
            </div>
            {/* main */}
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
              <div style={{ padding: '16px 20px 12px', borderBottom: '1px solid #1c1c1e' }}>
                <div style={{ fontSize: '16px', fontWeight: 660, letterSpacing: '-0.03em', color: '#fff' }}>Good afternoon, Tanya</div>
                <div style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '-0.01em', color: '#6e6e73', marginTop: '2px' }}>147 items across 6 spaces — 3 need attention</div>
              </div>
              <div style={{ padding: '12px 20px', display: 'flex', flexDirection: 'column', gap: '10px', overflow: 'hidden' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: '7px' }}>
                  {[['147','Items',false],['6','Spaces',false],['3','Attention',true]].map(([n,l,warn]) => (
                    <div key={l as string} style={{ background: '#111113', border: '1px solid #1c1c1e', borderRadius: '8px', padding: '11px 13px' }}>
                      <div style={{ fontSize: '20px', fontWeight: 700, letterSpacing: '-0.04em', color: warn ? '#ffd60a' : '#fff', lineHeight: 1 }}>{n as string}</div>
                      <div style={{ fontSize: '9px', fontWeight: 500, letterSpacing: '0.06em', textTransform: 'uppercase', color: '#6e6e73', marginTop: '4px' }}>{l as string}</div>
                    </div>
                  ))}
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '7px' }}>
                  <div style={{ background: '#111113', border: '1px solid #1c1c1e', borderRadius: '8px', padding: '11px 13px' }}>
                    <div style={{ fontSize: '9px', fontWeight: 510, letterSpacing: '0.06em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: '7px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <span style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#32d74b', animation: 'pulseDot 2s ease infinite', display: 'inline-block' }} />
                      Ask FindEZ
                    </div>
                    <div style={{ fontSize: '11px', letterSpacing: '-0.01em', color: '#a1a1a6', background: '#1c1c1e', borderRadius: '5px', padding: '6px 8px', marginBottom: '5px', lineHeight: 1.5 }}>
                      Do I have any M3 screws?
                      <span style={{ color: 'rgba(255,255,255,0.65)', display: 'block', marginTop: '2px' }}>Yes — 48× M3×8mm in Robotics.</span>
                    </div>
                  </div>
                  <div style={{ background: '#111113', border: '1px solid #1c1c1e', borderRadius: '8px', padding: '11px 13px' }}>
                    <div style={{ fontSize: '9px', fontWeight: 510, letterSpacing: '0.06em', textTransform: 'uppercase', color: '#6e6e73', marginBottom: '8px' }}>Spaces</div>
                    {[['Garage','34','70%'],['Kitchen','41','85%'],['Office','28','55%'],['Robotics','25','48%']].map(([n,c,w]) => (
                      <div key={n} style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '3px 0', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                        <div style={{ fontSize: '11px', fontWeight: 510, letterSpacing: '-0.015em', color: '#fff', flex: 1 }}>{n}</div>
                        <div style={{ fontSize: '10px', color: '#6e6e73', minWidth: '18px', textAlign: 'right' }}>{c}</div>
                        <div style={{ height: '2px', background: '#2c2c2e', borderRadius: '1px', overflow: 'hidden', width: '36px' }}>
                          <div style={{ height: '100%', width: w, borderRadius: '1px', background: '#3a3a3c' }} />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section id="pricing" style={{ padding: '72px 28px', textAlign: 'center', borderTop: '1px solid #1c1c1e', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', inset: 0, backgroundImage: 'linear-gradient(#1c1c1e 1px,transparent 1px),linear-gradient(90deg,#1c1c1e 1px,transparent 1px)', backgroundSize: '44px 44px', pointerEvents: 'none' }} />
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '80px', background: 'linear-gradient(#000,transparent)', pointerEvents: 'none' }} />
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '80px', background: 'linear-gradient(transparent,#000)', pointerEvents: 'none' }} />
        <h2 style={{ fontSize: '38px', fontWeight: 700, letterSpacing: '-0.042em', color: '#fff', marginBottom: '10px', position: 'relative', zIndex: 1 }}>Stop losing track of things.</h2>
        <p style={{ fontSize: '15px', fontWeight: 400, letterSpacing: '-0.018em', color: '#a1a1a6', marginBottom: '26px', position: 'relative', zIndex: 1 }}>Free to start. Works in your browser and on iPhone.</p>
        <Link href="/signup" style={{ display: 'inline-block', padding: '11px 24px', borderRadius: '8px', fontSize: '15px', fontWeight: 510, letterSpacing: '-0.02em', background: '#fff', color: '#000', textDecoration: 'none', position: 'relative', zIndex: 1 }}>Create your inventory →</Link>
      </section>

      {/* FOOTER */}
      <footer style={{ borderTop: '1px solid #1c1c1e', padding: '18px 28px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: '13px', fontWeight: 590, letterSpacing: '-0.025em', color: '#fff' }}>FindEZ</span>
        <span style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '-0.005em', color: '#6e6e73' }}>© 2026 FindEZ. All rights reserved.</span>
        <div style={{ display: 'flex', gap: '16px' }}>
          {['Privacy', 'Terms', 'Download iOS'].map(l => (
            <span key={l} style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '-0.005em', color: '#6e6e73', cursor: 'pointer' }}>{l}</span>
          ))}
        </div>
      </footer>

    </div>
  );
}
