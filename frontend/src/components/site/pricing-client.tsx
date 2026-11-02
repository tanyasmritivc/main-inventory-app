"use client";

import Link from "next/link";
import { useState } from "react";
import { BILLING_PLANS } from "@/lib/billing-plans";
import { isPilotPublic, PILOT_COPY } from "@/lib/pilot";
import { MarketingNav } from "@/components/site/marketing-nav";
import { MarketingFooter } from "@/components/site/product-marketing";

export function PricingClient() {
  const [annual, setAnnual] = useState(false);
  return (
    <div className="plans-page">
      <MarketingNav theme="light" />
      <main>
        <header className="plans-intro">
          <h1>A place for everything you remember.</h1>
          <p>Start free. Choose more room for your things and your team as you grow.</p>
          <p className="plans-notice">{isPilotPublic() ? PILOT_COPY.notice : "Paid plans are coming soon. No payment will be taken."}</p>
          <div className="plans-period" role="group" aria-label="Billing period">
            <button aria-pressed={!annual} onClick={() => setAnnual(false)}>Monthly</button>
            <button aria-pressed={annual} onClick={() => setAnnual(true)}>Yearly</button>
          </div>
        </header>
        <div className="plans-grid">
          {BILLING_PLANS.map(plan => {
            const price = annual ? plan.annual : plan.monthly;
            return <section className="plan-card" key={plan.id} aria-labelledby={`plan-${plan.id}`}>
              <h2 id={`plan-${plan.id}`}>{plan.name}</h2>
              <p className="plan-price">{price === null ? "Custom" : `$${price.toLocaleString("en-US")}`}<small>{price === null || price === 0 ? "" : annual ? "/year" : "/month"}</small></p>
              {annual && price !== null && price > 0 && <p className="plan-equivalent">About ${(price / 12).toFixed(2)}/month, billed yearly</p>}
              <ul>{plan.features.map(feature => <li key={feature}>{feature}</li>)}</ul>
              {plan.id === "free" ? <Link className="plan-action" href="/signup">Get started free</Link>
                : plan.id === "enterprise" ? <a className="plan-action" href="mailto:info@findez.ai?subject=FindEZ%20Enterprise">Contact us</a>
                : <button className="plan-action" disabled aria-label={`${plan.name} subscriptions coming soon`}>Coming soon</button>}
            </section>;
          })}
        </div>
        <p className="plans-footnote">Planned pricing in USD. Paid plans and their limits will be available when subscriptions launch. Current access is unchanged. <Link href="/terms">Terms</Link> · <Link href="/privacy">Privacy</Link></p>
      </main>
      <MarketingFooter theme="light" />
      <style>{`
        .plans-page { background:#f7f7f5; color:#202022; min-height:100vh; font-family:var(--font-inter,Arial,sans-serif); }
        .plans-page .marketing-nav-wrap { background:#fff; }
        .plans-intro { max-width:720px; margin:auto; padding:80px 24px 36px; text-align:center; }
        .plans-intro h1 { font-size:clamp(30px,5vw,48px); font-weight:500; letter-spacing:-.035em; line-height:1.15; }
        .plans-intro p { color:#626267; line-height:1.6; }
        .plans-notice { font-size:13px; }
        .plans-period { display:inline-flex; padding:4px; background:#ececed; border:1px solid #dddde0; border-radius:99px; margin-top:16px; }
        .plans-period button { padding:10px 22px; border:0; border-radius:99px; background:transparent; color:#636368; cursor:pointer; }
        .plans-period button[aria-pressed=true] { background:#fff; color:#202022; box-shadow:0 1px 5px #00000010; }
        .plans-grid { max-width:1200px; margin:auto; padding:0 24px; display:grid; grid-template-columns:repeat(auto-fit,minmax(205px,1fr)); gap:14px; }
        .plan-card { padding:24px 20px; background:#fff; border:1px solid #e5e5e8; border-radius:22px; display:flex; flex-direction:column; }
        .plan-card h2 { font-size:19px; font-weight:500; margin:0 0 24px; }
        .plan-price { font-size:32px; letter-spacing:-.04em; margin:0; }
        .plan-price small { font-size:13px; letter-spacing:0; color:#66666c; }
        .plan-equivalent { font-size:12px; color:#66666c; line-height:1.5; }
        .plan-card ul { flex:1; list-style:none; padding:0; margin:28px 0; font-size:13px; line-height:1.65; }
        .plan-card li { margin-bottom:12px; }
        .plan-action { min-height:44px; padding:10px 12px; text-align:center; border:1px solid #dddde1; border-radius:12px; background:linear-gradient(150deg,#fff,#eeeeef); color:#29292c; font-size:13px; text-decoration:none; }
        .plan-action:disabled { color:#727277; background:#f4f4f5; }
        .plans-footnote { max-width:760px; margin:32px auto 64px; padding:0 24px; color:#66666b; font-size:12px; line-height:1.6; text-align:center; }
        .plans-footnote a { text-decoration:underline; }
        .plans-page button:focus-visible,.plans-page a:focus-visible { outline:2px solid #5c5c66; outline-offset:4px; }
      `}</style>
    </div>
  );
}
