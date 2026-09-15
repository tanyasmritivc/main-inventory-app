import type { Metadata } from "next";
import Link from "next/link";

import { ProductCta, ProductHero, ProductMarketingShell, ProductPageStyles } from "@/components/site/product-marketing";

export const metadata: Metadata = {
  title: { absolute: "FindEZ — Build your inventory from the real world" },
  description: "Capture items from photos, barcodes, or spreadsheets, then search or ask FindEZ what you have and where it is.",
};

const CAPABILITIES = [
  { number: "01", title: "Capture Items", body: "Turn photos, barcodes, spreadsheets, and quick manual entries into organized inventory.", href: "/product/capture" },
  { number: "02", title: "Ask FindEZ", body: "Ask what you own, where it is, or tell FindEZ to make a common inventory change.", href: "/product/ask" },
  { number: "03", title: "Spaces & Sharing", body: "Match inventory to real-world locations and give your team the right access.", href: "/product/spaces-and-sharing" },
];

export default function LandingPage() {
  return (
    <ProductMarketingShell>
      <ProductHero
        eyebrow="One intelligent inventory"
        title={<>Build your inventory from the real world.<br />Find anything in seconds.</>}
        description="Capture items from photos, barcodes, or spreadsheets—then search or ask FindEZ what you have and where it is."
      >
        <div className="product-actions">
          <Link href="/signup" className="product-button product-button--primary">Get started free</Link>
          <Link href="/product" className="product-button product-button--secondary">See how FindEZ works</Link>
        </div>
      </ProductHero>

      <section className="product-section product-wrap">
        <div className="product-section__intro">
          <div className="product-eyebrow">Inventory without the busywork</div>
          <h2>One product from capture to retrieval.</h2>
          <p>Build a reliable record of the physical things around you, organize it the way your world is organized, and get to the right item fast.</p>
        </div>
        <div className="product-card-grid">
          {CAPABILITIES.map((capability) => (
            <article className="product-card" key={capability.href}>
              <span className="product-card__number">{capability.number}</span>
              <h3>{capability.title}</h3>
              <p>{capability.body}</p>
              <Link href={capability.href}>Explore {capability.title} →</Link>
            </article>
          ))}
        </div>
      </section>

      <section className="product-section product-section--bordered">
        <div className="product-wrap">
          <div className="product-section__intro">
            <div className="product-eyebrow">Ask your inventory</div>
            <h2>Get an answer grounded in what you actually have.</h2>
            <p>Search directly or use everyday language to find items, check quantities, and handle common updates.</p>
          </div>
          <div className="product-demo">
            <div className="product-demo__bar"><span /><span /><span /></div>
            <div className="product-demo__content">
              <div className="product-demo__prompt">Where are the motor controllers?</div>
              <div className="product-demo__answer">You have 6 motor controllers in Robot Parts—4 on the electronics shelf and 2 in the competition case.</div>
            </div>
          </div>
        </div>
      </section>
      <ProductCta />
      <ProductPageStyles />
    </ProductMarketingShell>
  );
}
