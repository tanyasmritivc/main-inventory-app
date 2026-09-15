import type { Metadata } from "next";

import { ProductCta, ProductHero, ProductMarketingShell, ProductPageStyles } from "@/components/site/product-marketing";

export const metadata: Metadata = { title: "Spaces & Sharing", description: "Organize inventory by real-world location and share it with your team." };

export default function SpacesAndSharingPage() {
  return (
    <ProductMarketingShell>
      <ProductHero eyebrow="Spaces & Sharing" title={<>Organized like your world.<br />Shared with your people.</>} description="A Space represents a real-world location. Sharing controls who can see or edit the inventory inside it." />
      <section className="product-section product-wrap">
        <div className="product-section__intro"><div className="product-eyebrow">Physical organization</div><h2>Give every item a place.</h2><p>Create Spaces for the locations that matter to you—from a workshop or storeroom to a competition pit. Search across them or open one Space to work with its inventory.</p></div>
        <div className="product-card-grid product-card-grid--two">
          <article className="product-card"><span className="product-card__number">SPACES</span><h3>Reflect real locations</h3><p>Group inventory where it physically lives, then create, import, scan, search, and manage items in that context.</p></article>
          <article className="product-card"><span className="product-card__number">SHARING</span><h3>Work from one inventory</h3><p>Share a Space with a join code and choose view or edit access so everyone works from the same record.</p></article>
        </div>
      </section>
      <section className="product-section product-section--bordered"><div className="product-wrap">
        <div className="product-section__intro"><div className="product-eyebrow">Access that fits the team</div><h2>Share visibility without giving up control.</h2><p>Owners can manage members and access while teammates see the inventory they need. Editors can help keep shared Spaces current.</p></div>
        <div className="product-facts"><div className="product-fact"><strong>Create</strong><span>Set up Spaces for real-world locations.</span></div><div className="product-fact"><strong>Invite</strong><span>Bring people in with a share or join code.</span></div><div className="product-fact"><strong>Control</strong><span>Choose view or edit permission.</span></div><div className="product-fact"><strong>Manage</strong><span>Review members and remove access.</span></div></div>
      </div></section>
      <ProductCta /><ProductPageStyles />
    </ProductMarketingShell>
  );
}
