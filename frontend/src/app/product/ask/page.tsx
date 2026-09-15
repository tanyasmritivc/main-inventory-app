import type { Metadata } from "next";

import { ProductCta, ProductHero, ProductMarketingShell, ProductPageStyles } from "@/components/site/product-marketing";

export const metadata: Metadata = { title: "Ask FindEZ", description: "Ask what you own, where it is, or tell FindEZ to update your inventory." };
const PROMPTS = ["Where are the motor controllers?", "How many safety glasses do we have?", "Add five bearings to Robot Parts.", "What is running low?"];

export default function AskPage() {
  return (
    <ProductMarketingShell>
      <ProductHero eyebrow="Ask FindEZ" title={<>Your inventory,<br />in everyday language.</>} description="Ask what you own, where it is, or tell FindEZ to update your inventory." />
      <section className="product-section product-wrap">
        <div className="product-section__intro"><div className="product-eyebrow">Ask or act</div><h2>Go from a question to the right item in seconds.</h2><p>Ask FindEZ works against your inventory, so questions about locations and quantities lead back to the items and Spaces you maintain.</p></div>
        <div className="product-demo"><div className="product-demo__bar"><span /><span /><span /></div><div className="product-demo__content">{PROMPTS.map((prompt) => <div className="product-demo__prompt" key={prompt}>{prompt}</div>)}</div></div>
      </section>
      <section className="product-section product-section--bordered"><div className="product-wrap"><div className="product-card-grid product-card-grid--two">
        <article className="product-card"><span className="product-card__number">FIND</span><h3>Retrieve inventory information</h3><p>Check whether you have an item, where it is stored, and how many are available.</p></article>
        <article className="product-card"><span className="product-card__number">UPDATE</span><h3>Handle common inventory actions</h3><p>Add items and quantities using a straightforward instruction, without navigating a long form.</p></article>
      </div></div></section>
      <ProductCta /><ProductPageStyles />
    </ProductMarketingShell>
  );
}
