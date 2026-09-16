import type { Metadata } from "next";
import { Check, MapPin, Minus, Plus, Search, Sparkles } from "lucide-react";

import { ProductDetailCta, ProductDetailHero, ProductDetailShell, productDetailStyles as detail } from "@/components/site/product-detail";

import visual from "../product-visuals.module.css";

export const metadata: Metadata = { title: "Ask FindEZ", description: "Ask FindEZ what you own, how many you have, where it is, or update inventory in everyday language." };

function AskDemo() {
  return (
    <div className={visual.askCanvas} aria-label="Ask FindEZ answering from an inventory record">
      <div className={visual.askTop}><span><Sparkles size={14} /> Ask FindEZ</span><span>Inventory connected</span></div>
      <div className={visual.question}><Search size={16} /> Where are the 608 bearings?</div>
      <div className={visual.answer}><span><MapPin size={19} /></span><div><small>34 in stock</small><strong>Machine shop · Drawer A04</strong><p>Found across 2 inventory records</p></div></div>
      <div className={visual.sourceRecord}><strong>608 bearing · Part #608-ZZ</strong><span>Open item →</span></div>
    </div>
  );
}

export default function AskPage() {
  return (
    <ProductDetailShell>
      <ProductDetailHero
        label="Ask FindEZ"
        title="Ask where it is. Update it there."
        description="Ask what you have, how many are available, or where an item lives. Common changes can be made from the same conversation."
        visual={<AskDemo />}
      />

      <section className={detail.contentSection}>
        <div className={detail.sectionHeader}><span>Questions backed by inventory</span><h2>Answers lead back to the record.</h2><p>Ask FindEZ uses the items and Spaces you maintain, so you can inspect the source instead of trusting a disconnected answer.</p></div>
        <div className={visual.exampleGrid}>
          <article className={visual.example}><span>Location</span><strong>“Where are the motor controllers?”</strong><small>Returns the Space and stored location.</small></article>
          <article className={visual.example}><span>Quantity</span><strong>“How many safety glasses do we have?”</strong><small>Uses the quantities in your inventory.</small></article>
          <article className={visual.example}><span>Availability</span><strong>“What is running low?”</strong><small>Surfaces low quantities that need attention.</small></article>
          <article className={visual.example}><span>Details</span><strong>“Which bearing is part 608-ZZ?”</strong><small>Finds the matching item record.</small></article>
        </div>
      </section>

      <section className={detail.greenSection}>
        <div className={detail.greenInner}>
          <div className={detail.greenCopy}><span>Ask or act</span><h2>Make a clear change without a long form.</h2><p>Tell FindEZ what should change, review the affected item and quantity, then confirm the update.</p></div>
          <div className={visual.actionPanel}>
            <div className={visual.actionPrompt}><Sparkles size={15} /> Add five bearings to Robot Parts.</div>
            <div className={visual.changePreview}>
              <span>Proposed inventory change</span>
              <div className={visual.changeRow}><strong>608 bearing</strong><div><b><Minus size={11} /> 2</b><span>→</span><b><Plus size={11} /> 7</b></div></div>
              <div className={visual.confirm}><Check size={13} /> Review and confirm</div>
            </div>
          </div>
        </div>
      </section>

      <ProductDetailCta title="Ask your inventory directly." body="Find the item, quantity, or location you need." />
    </ProductDetailShell>
  );
}
