"use client";

import Link from "next/link";
import { PlanComparison } from "./plan-comparison";
import { PLAN_POLICIES, PLANS_NOTICE } from "@/lib/billing-plans";

export function PricingClient() {
  return (
    <div className="plans-page">
      <main>
        <header className="plans-intro">
          <h1>Remember more of your world.</h1>
          <p>Start free. Add more of your things, or share them with your team.</p>
          <p className="plans-notice">{PLANS_NOTICE}</p>
        </header>
        <div className="public-plan-comparison"><PlanComparison/></div>
        <section className="plans-details" aria-labelledby="plan-details-title">
          <h2 id="plan-details-title">How the planned limits work</h2>
          <dl>{PLAN_POLICIES.map(([title, detail]) => <div key={title}><dt>{title}</dt><dd>{detail}</dd></div>)}</dl>
          <p>Need a larger team? <a href="mailto:info@findez.ai?subject=FindEZ%20larger%20team">Contact us</a>.</p>
        </section>
        <section className="plans-details plans-faq" aria-labelledby="plans-faq-title">
          <h2 id="plans-faq-title">Before you choose</h2>
          <details><summary>Can I use FindEZ for free now?</summary><p>Yes. During pre-launch, access is free and plan quotas are not enforced. There is no automatic cutoff or automatic charge. The cards show the planned subscription allowances.</p></details>
          <details><summary>Which plan is intended for me?</summary><p>Free is a starting point for a small personal inventory. Plus is designed for a larger home, collection or workshop. Team is for a shared inventory with up to ten people and pooled AI allowances.</p></details>
          <details><summary>What changes with yearly billing?</summary><p>The Yearly option shows the full planned annual payment and its monthly equivalent. Item and people allowances stay the same; photo and AI message allowances are still monthly.</p></details>
          <details><summary>Can I subscribe or enter payment details?</summary><p>Paid subscriptions are not available yet. You can create an account without payment details. We will explain billing and subscription management before paid plans launch.</p></details>
          <details><summary>What if my team has more than ten people?</summary><p><a href="mailto:info@findez.ai?subject=FindEZ%20larger%20team">Contact us</a> about your team and the inventory you manage.</p></details>
        </section>
        <p className="plans-footnote">Planned pricing in USD. All plan allowances start when subscriptions launch. AI allowances may be adjusted before launch based on measured usage. Current access is unchanged. <Link href="/terms">Terms</Link> · <Link href="/privacy">Privacy</Link></p>
      </main>
      <style>{`
        .public-plan-comparison { max-width:1080px; margin:auto; padding:0 24px; }
        .plans-page { --ink:#202022; --light-panel:#fff; --light-raised:#f4f4f5; --light-line:#e5e5e8; --light-line-strong:#dddde1; --light-muted:#626267; --control-primary:#111112; --control-on-primary:#fff; background:#fff; color:#202022; min-height:100vh; font-family:var(--font-body,Arial,sans-serif); }
        .plans-page .marketing-nav-wrap { background:#fff; }
        .plans-intro { max-width:720px; margin:auto; padding:132px 24px 36px; text-align:center; }
        .plans-intro h1 { font-size:clamp(30px,5vw,48px); font-weight:500; letter-spacing:-.035em; line-height:1.15; }
        .plans-intro p { color:#626267; line-height:1.6; }
        .plans-notice { font-size:13px; }
        .plans-details { max-width:900px; margin:48px auto 0; padding:0 24px; font-size:14px; line-height:1.6; }
        .plans-details h2 { font-size:22px; font-weight:500; letter-spacing:-.02em; }
        .plans-details dl { display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr)); gap:24px; margin:24px 0 32px; }
        .plans-details dt { font-weight:500; }
        .plans-details dd { margin:6px 0 0; color:#626267; }
        .plans-details a { color:#202022; text-decoration:underline; }
        .plans-faq { margin-top:56px; }
        .plans-faq h2 { margin-bottom:22px; }
        .plans-faq details { border-top:1px solid #e5e5e8; padding:18px 0; }
        .plans-faq summary { cursor:pointer; font-size:15px; font-weight:500; padding-right:16px; }
        .plans-faq details p { color:#626267; margin:12px 0 0; max-width:720px; }
        .plans-footnote { max-width:760px; margin:32px auto 64px; padding:0 24px; color:#66666b; font-size:12px; line-height:1.6; text-align:center; }
        .plans-footnote a { text-decoration:underline; }
        .plans-page button:focus-visible,.plans-page a:focus-visible { outline:2px solid #5c5c66; outline-offset:4px; }
      `}</style>
    </div>
  );
}
