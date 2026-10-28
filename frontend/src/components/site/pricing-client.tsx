"use client";

import Link from "next/link";
import { PublicPlanCards } from "@/components/pages-ui/PublicPlanCards";
import { BlurText, HeroBackdrop } from "@/components/pages-ui/cards";
import { PLAN_POLICIES, PLANS_NOTICE } from "@/lib/billing-plans";

export function PricingClient() {
  return (
    <div className="plans-page">
      <main>
        <header className="plans-intro"><HeroBackdrop/>
          <h1><BlurText>Remember more of your world.</BlurText></h1>
          <p>Start free. Add more of your things, or share them with your team.</p>
          <p className="plans-notice">{PLANS_NOTICE}</p>
        </header>
        <div className="pages-column"><div className="public-plan-comparison" data-reveal><PublicPlanCards/></div>
        <section className="plans-details" aria-labelledby="plan-details-title">
          <h2 id="plan-details-title">How the planned limits work</h2>
          <dl>{PLAN_POLICIES.map(([title, detail]) => <div key={title} data-spotlight data-reveal><dt>{title}</dt><dd>{detail}</dd></div>)}</dl>
          <p className="pages-strip">Need a larger team? <span><a className="public-primary" href="mailto:info@findez.ai?subject=FindEZ%20larger%20team">Contact us</a>.</span></p>
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
      </div></main>

    </div>
  );
}
