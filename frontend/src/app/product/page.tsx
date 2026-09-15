import type { Metadata } from "next";
import Link from "next/link";

import { ProductCta, ProductHero, ProductMarketingShell, ProductPageStyles } from "@/components/site/product-marketing";

export const metadata: Metadata = {
  title: "Product Overview",
  description: "See how FindEZ helps you capture, organize, find, and share one living inventory.",
};

const STEPS = [
  { title: "Capture", body: "Add multiple items from a photo, scan a barcode, import a spreadsheet, or enter an item manually." },
  { title: "Organize", body: "Place items in Spaces that mirror your shop, storeroom, classroom, garage, or competition pit." },
  { title: "Find", body: "Search across Spaces or ask FindEZ what you have, how many, and where each item is." },
  { title: "Share", body: "Invite the people you work with and choose whether they can view or edit each shared Space." },
];

export default function ProductPage() {
  return (
    <ProductMarketingShell>
      <ProductHero eyebrow="FindEZ Inventory" title={<>One living inventory.<br />Always ready to answer.</>} description="FindEZ turns the physical things around you into an inventory your team can build, understand, and use together." />
      <section className="product-section product-wrap">
        <div className="product-section__intro">
          <div className="product-eyebrow">The complete loop</div>
          <h2>Capture. Organize. Find. Share.</h2>
          <p>Every FindEZ capability supports one continuous job: keeping a useful, accurate picture of what you have and where it is.</p>
        </div>
        <div className="product-flow">
          {STEPS.map((step) => <article className="product-flow__step" key={step.title}><h3>{step.title}</h3><p>{step.body}</p></article>)}
        </div>
      </section>
      <section className="product-section product-section--bordered">
        <div className="product-wrap">
          <div className="product-section__intro">
            <div className="product-eyebrow">Explore the product</div>
            <h2>Built around the work, not the technology.</h2>
          </div>
          <div className="product-card-grid">
            <article className="product-card"><span className="product-card__number">01</span><h3>Capture Items</h3><p>Build inventory quickly from the inputs you already have.</p><Link href="/product/capture">Explore Capture →</Link></article>
            <article className="product-card"><span className="product-card__number">02</span><h3>Ask FindEZ</h3><p>Find information and make changes in everyday language.</p><Link href="/product/ask">Explore Ask FindEZ →</Link></article>
            <article className="product-card"><span className="product-card__number">03</span><h3>Spaces & Sharing</h3><p>Connect your inventory to real places and real teams.</p><Link href="/product/spaces-and-sharing">Explore Spaces & Sharing →</Link></article>
          </div>
        </div>
      </section>
      <ProductCta />
      <ProductPageStyles />
    </ProductMarketingShell>
  );
}
