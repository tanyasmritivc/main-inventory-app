"use client";
import Link from "next/link";
import { useId, useState } from "react";
import { Check } from "lucide-react";
import { BILLING_PLANS } from "@/lib/billing-plans";

/** Public presentation only; the catalog and disabled subscription behavior are unchanged. */
export function PublicPlanCards(){
 const [annual,setAnnual]=useState(false);const id=useId();
 return <><div className="pages-period-row"><span>Planned pricing · USD</span><div className="pages-period" data-annual={annual} role="group" aria-label="Billing period"><button type="button" aria-pressed={!annual} onClick={()=>setAnnual(false)}>Monthly</button><button type="button" aria-pressed={annual} onClick={()=>setAnnual(true)}>Yearly</button></div></div>
 <div className="pages-plans">{BILLING_PLANS.map(plan=>{const price=annual?plan.annual:plan.monthly;return <section className={`pages-plan${plan.id==="team"?" pages-gradient grain g-ember plan-featured":""}`} data-loop key={plan.id} aria-labelledby={`${id}-${plan.id}`}>
 <h2 id={`${id}-${plan.id}`}>{plan.name}</h2><p className="plan-description">{plan.description}</p>
 <p className="plan-price"><span aria-hidden="true">$<span data-count={price}>{price.toLocaleString("en-US")}</span></span><span className="pages-sr-only">{`$${price.toLocaleString("en-US")}`}</span><small>{price===0?"":annual?"/year":"/month"}</small></p>
 <p className="plan-billing" key={String(annual)}>{annual&&price>0?`About $${(price/12).toFixed(2)}/month, billed yearly`:price===0?"No payment details needed":"Billed monthly"}</p>
 <ul>{plan.features.map(feature=><li key={feature}><Check size={14} aria-hidden="true"/><span>{feature}</span></li>)}</ul>
 {plan.id!=="free"?<button disabled aria-label={`${plan.name} subscriptions coming soon`}>Coming soon</button>:<Link className="public-primary" href="/signup">Get started free</Link>}
 </section>;})}</div></>;
}
