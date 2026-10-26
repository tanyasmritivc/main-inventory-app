"use client";

import Link from "next/link";
import { useId, useState } from "react";
import { Check } from "lucide-react";
import { BILLING_PLANS } from "@/lib/billing-plans";
import styles from "./plans-usage.module.css";

/** One display catalog for marketing, the welcome dialog and account settings.
 * These are future allowances, never a source of entitlement or a checkout. */
export function PlanComparison({ onContinue, signedIn = false }: {
  onContinue?: () => void;
  signedIn?: boolean;
}) {
  const [annual, setAnnual] = useState(false);
  const id = useId();
  return <div className={styles.comparison}>
    <div className={styles.compareHeading}>
      <span className={styles.muted}>Planned pricing · USD</span>
      <div className={styles.period} role="group" aria-label="Billing period">
        <button type="button" aria-pressed={!annual} onClick={() => setAnnual(false)}>Monthly</button>
        <button type="button" aria-pressed={annual} onClick={() => setAnnual(true)}>Yearly</button>
      </div>
    </div>
    <div className={styles.grid}>
      {BILLING_PLANS.map(plan => {
        const price = annual ? plan.annual : plan.monthly;
        return <section className={styles.card} key={plan.id} aria-labelledby={`${id}-${plan.id}`}>
          <h2 id={`${id}-${plan.id}`}>{plan.name}</h2>
          <p className={styles.description}>{plan.description}</p>
          <p className={styles.price}>{`$${price.toLocaleString("en-US")}`}<small>{price === 0 ? "" : annual ? "/year" : "/month"}</small></p>
          <p className={styles.equivalent}>{annual && price > 0 ? `About $${(price / 12).toFixed(2)}/month, billed yearly` : price === 0 ? "No payment details needed" : "Billed monthly"}</p>
          <ul>{plan.features.map(feature => <li key={feature}><Check size={14} aria-hidden="true"/><span>{feature}</span></li>)}</ul>
          {plan.id !== "free"
            ? <button className={styles.secondary} disabled aria-label={`${plan.name} subscriptions coming soon`}>Coming soon</button>
            : onContinue
              ? <button className={styles.primary} onClick={onContinue}>Continue with Free</button>
              : signedIn
                ? <Link className={styles.secondary} href="/worlds">Back to FindEZ</Link>
                : <Link className={styles.primary} href="/signup">Get started free</Link>}
        </section>;
      })}
    </div>
  </div>;
}
