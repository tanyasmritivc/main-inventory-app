import type { Metadata } from "next";
import { Boxes, Eye, Link2, MapPin, Pencil, Users } from "lucide-react";

import { ProductDetailCta, ProductDetailHero, ProductDetailShell, productDetailStyles as detail } from "@/components/site/product-detail";

import visual from "../product-visuals.module.css";

export const metadata: Metadata = { title: "Spaces & Sharing", description: "Organize FindEZ inventory by real-world location and share the right access with your team." };

function SpacesDemo() {
  return (
    <div className={visual.spacesCanvas} aria-label="FindEZ inventory organized into physical Spaces">
      <div className={visual.inventoryNode}><span><Boxes size={18} /></span><strong>Your inventory</strong><small>525 items</small></div>
      <span className={visual.branch} />
      <div className={visual.locationList}>
        <div><span><MapPin size={15} /></span><p><strong>Machine shop</strong><small>267 items</small></p></div>
        <div><span><MapPin size={15} /></span><p><strong>Electronics bench</strong><small>168 items</small></p></div>
        <div><span><MapPin size={15} /></span><p><strong>Competition pit</strong><small>90 items</small></p></div>
      </div>
      <div className={visual.sharedTag}><Users size={13} /> Shared with Sample Team</div>
    </div>
  );
}

export default function SpacesAndSharingPage() {
  return (
    <ProductDetailShell>
      <ProductDetailHero
        label="Spaces & sharing"
        title="A Space is where inventory lives."
        description="Create a Space for a room, cabinet, shelf, or competition pit. The items inside keep that location wherever your team views them."
        visual={<SpacesDemo />}
      />

      <section className={detail.contentSection}>
        <div className={detail.sectionHeader}><span>Physical organization</span><h2>Build the same map your team uses.</h2><p>Open one Space to work locally or search across every Space when you only know the item.</p></div>
        <div className={detail.featureGrid}>
          <article className={detail.feature}><span className={detail.featureIcon}><MapPin size={18} /></span><h3>Real locations</h3><p>Use the names people already know: Machine shop, Cabinet B, or Drawer A04.</p></article>
          <article className={detail.feature}><span className={detail.featureIcon}><Boxes size={18} /></span><h3>Inventory in context</h3><p>Scan, import, search, and update items without losing where they belong.</p></article>
          <article className={detail.feature}><span className={detail.featureIcon}><Link2 size={18} /></span><h3>One shared record</h3><p>Link a Space to a team instead of maintaining a second copy of the inventory.</p></article>
        </div>
      </section>

      <section className={detail.greenSection}>
        <div className={detail.greenInner}>
          <div className={detail.greenCopy}><span>Controlled sharing</span><h2>Share access, not duplicate lists.</h2><p>Invite people with a join code and decide who can view inventory and who can keep it current.</p></div>
          <div className={visual.permissionPanel}>
            <div className={visual.permissionHeader}><strong>Machine shop</strong><span>3 members</span></div>
            <div className={visual.member}><span className={visual.avatar}>TV</span><div><strong>Tanya Victor</strong><small>Space owner</small></div><span className={visual.role}>Owner</span></div>
            <div className={visual.member}><span className={visual.avatar}><Pencil size={13} /></span><div><strong>Build lead</strong><small>Can update inventory</small></div><span className={visual.role}>Edit</span></div>
            <div className={visual.member}><span className={visual.avatar}><Eye size={13} /></span><div><strong>Team member</strong><small>Can view inventory</small></div><span className={visual.role}>View</span></div>
          </div>
        </div>
      </section>

      <ProductDetailCta title="Give every item a real home." body="Create a Space, add inventory, and invite your team." />
    </ProductDetailShell>
  );
}
