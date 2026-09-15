import type { Metadata } from "next";

import { ProductCta, ProductHero, ProductMarketingShell, ProductPageStyles } from "@/components/site/product-marketing";

export const metadata: Metadata = { title: "Capture Items", description: "Turn photos, barcodes, spreadsheets, and manual entries into organized FindEZ inventory." };

const METHODS = [
  { title: "Photo scanning", body: "Photograph a shelf, bin, or workbench to start an inventory." },
  { title: "Multi-item extraction", body: "Identify several visible items from one image and review them together." },
  { title: "Barcode lookup", body: "Scan a product barcode to look it up and add it faster." },
  { title: "Spreadsheet import", body: "Bring an existing inventory into FindEZ without starting over." },
  { title: "Manual entry", body: "Create or edit an item directly whenever that is the fastest route." },
];

export default function CapturePage() {
  return (
    <ProductMarketingShell>
      <ProductHero eyebrow="Capture Items" title={<>Turn what you see<br />into organized inventory.</>} description="Use photos, barcodes, spreadsheets, or a quick manual entry. They all lead to the same useful inventory." />
      <section className="product-section product-wrap">
        <div className="product-section__intro"><div className="product-eyebrow">Start from anywhere</div><h2>Choose the fastest input for the job.</h2><p>Capture a group of items in a photo, scan one product, migrate an existing list, or add the details yourself. You stay in control before items enter your inventory.</p></div>
        <div className="product-methods">{METHODS.map((method) => <article className="product-method" key={method.title}><strong>{method.title}</strong><span>{method.body}</span></article>)}</div>
      </section>
      <section className="product-section product-section--bordered"><div className="product-wrap">
        <div className="product-section__intro"><div className="product-eyebrow">One destination</div><h2>Every capture method builds the same inventory.</h2><p>However an item arrives, it can be organized into a Space, found through search, and used by the people you share it with.</p></div>
        <div className="product-facts">
          <div className="product-fact"><strong>Review</strong><span>Check extracted item details before saving.</span></div><div className="product-fact"><strong>Organize</strong><span>Place items in the Space where they live.</span></div><div className="product-fact"><strong>Update</strong><span>Edit quantities and details as inventory changes.</span></div><div className="product-fact"><strong>Find</strong><span>Search or ask for the item later.</span></div>
        </div>
      </div></section>
      <ProductCta /><ProductPageStyles />
    </ProductMarketingShell>
  );
}
