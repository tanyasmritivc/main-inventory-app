import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  Barcode,
  Camera,
  Check,
  FileSpreadsheet,
  MapPin,
  Package,
  Search,
  Sparkles,
  Users,
} from "lucide-react";

import { MarketingNav } from "@/components/site/marketing-nav";
import { MarketingFooter } from "@/components/site/product-marketing";

import styles from "./product.module.css";

export const metadata: Metadata = {
  title: "Product Overview",
  description: "See how FindEZ turns photos, scans, and spreadsheets into organized inventory your team can search.",
};

const inputs = [
  { label: "Photo", detail: "Identify a bin or shelf", icon: Camera },
  { label: "Barcode", detail: "Look up one item", icon: Barcode },
  { label: "Spreadsheet", detail: "Import existing rows", icon: FileSpreadsheet },
];

export default function ProductPage() {
  return (
    <div className={styles.page}>
      <MarketingNav theme="light" />

      <main>
        <section className={styles.hero}>
          <div className={styles.heroCopy}>
            <h1>From a photo to a place you can search.</h1>
            <p>FindEZ turns physical items into organized inventory—then keeps the item, quantity, and location together.</p>
            <div className={styles.heroActions}>
              <Link href="/signup" className={styles.primaryButton}>Start free <ArrowRight size={15} /></Link>
              <a href="#capture" className={styles.secondaryLink}>See the workflow</a>
            </div>
          </div>

          <div className={styles.heroSystem} aria-label="A photo becoming searchable FindEZ inventory">
            <div className={styles.systemHeader}>
              <span>New inventory</span>
              <span className={styles.liveStatus}><i /> Ready</span>
            </div>
            <div className={styles.systemBody}>
              <div className={styles.sourceCard}>
                <span className={styles.cardLabel}><Camera size={13} /> Source photo</span>
                <div className={styles.sourcePhoto}>
                  <Image src="/images/findez-parts-bin.jpg" alt="A workshop parts bin" fill priority sizes="300px" />
                  <span className={styles.focusBox} />
                </div>
              </div>

              <div className={styles.systemPath} aria-hidden="true"><span /><i /></div>

              <div className={styles.recordCard}>
                <span className={styles.cardLabel}><Sparkles size={13} /> FindEZ record</span>
                <div className={styles.recordTitle}>
                  <span><Package size={16} /></span>
                  <div><strong>608 bearing</strong><small>Part · 2 units</small></div>
                </div>
                <div className={styles.recordField}><span>Location</span><strong>Machine shop</strong></div>
                <div className={styles.recordField}><span>Stored in</span><strong>Drawer A04</strong></div>
                <div className={styles.recordReady}><Check size={13} /> Searchable by your team</div>
              </div>
            </div>
          </div>
        </section>

        <div className={styles.inputRail} aria-label="Ways to add inventory">
          {inputs.map((input) => {
            const Icon = input.icon;
            return (
              <div key={input.label}>
                <span><Icon size={17} /></span>
                <p><strong>{input.label}</strong><small>{input.detail}</small></p>
              </div>
            );
          })}
        </div>

        <section id="capture" className={`${styles.section} ${styles.captureSection}`}>
          <div className={styles.sectionCopy}>
            <span className={styles.stepNumber}>01</span>
            <h2>Bring in the inventory you already have.</h2>
            <p>Photograph a group of parts, scan a code, or import a spreadsheet. Review the result before anything is saved.</p>
            <Link href="/product/capture">Explore capture <ArrowRight size={14} /></Link>
          </div>

          <div className={styles.captureVisual}>
            <div className={styles.capturePhoto}>
              <Image src="/images/findez-parts-bin.jpg" alt="Parts being identified inside a workshop bin" fill sizes="(max-width: 800px) 90vw, 540px" />
              <span className={`${styles.itemBox} ${styles.boxOne}`}><i>608 bearing</i></span>
              <span className={`${styles.itemBox} ${styles.boxTwo}`}><i>M8 bolt</i></span>
              <span className={`${styles.itemBox} ${styles.boxThree}`}><i>XT60</i></span>
              <span className={styles.captureScan} aria-hidden="true" />
            </div>
            <div className={styles.reviewCard}>
              <header><span>Review</span><b>10 items</b></header>
              <div><Check size={13} /><strong>608 bearing</strong><span>×2</span></div>
              <div><Check size={13} /><strong>M8 bolt</strong><span>×7</span></div>
              <div><Check size={13} /><strong>XT60 connector</strong><span>×1</span></div>
            </div>
          </div>
        </section>

        <section id="organize" className={styles.organizeSection}>
          <div className={styles.organizeInner}>
            <div className={styles.organizeGraphic}>
              <div className={styles.inventoryNode}>
                <span><Package size={18} /></span>
                <strong>Your inventory</strong>
                <small>525 items</small>
              </div>
              <span className={styles.treeLine} aria-hidden="true" />
              <div className={styles.spaceList}>
                <div><span><MapPin size={15} /></span><p><strong>Machine shop</strong><small>267 items</small></p></div>
                <div><span><MapPin size={15} /></span><p><strong>Electronics bench</strong><small>168 items</small></p></div>
                <div><span><MapPin size={15} /></span><p><strong>Competition pit</strong><small>90 items</small></p></div>
              </div>
              <div className={styles.teamPill}><Users size={14} /> Shared with Sample Team</div>
            </div>

            <div className={styles.sectionCopyLight}>
              <span className={styles.stepNumberLight}>02</span>
              <h2>Organize it like the real space.</h2>
              <p>Spaces represent the rooms, shelves, cabinets, and bins where items actually live. Share a Space when other people need the same inventory.</p>
              <Link href="/product/spaces-and-sharing">Explore Spaces & sharing <ArrowRight size={14} /></Link>
            </div>
          </div>
        </section>

        <section id="find" className={`${styles.section} ${styles.findSection}`}>
          <div className={styles.sectionCopy}>
            <span className={styles.stepNumber}>03</span>
            <h2>Find the answer, not another list.</h2>
            <p>Search when you know the item. Ask FindEZ when you know the question. Both lead back to the same inventory record and location.</p>
            <div className={styles.findModes}>
              <span><Search size={15} /><b>Search</b> names, part numbers, or locations</span>
              <span><Sparkles size={15} /><b>Ask</b> what you have, how many, and where</span>
            </div>
            <Link href="/product/ask">Explore Ask FindEZ <ArrowRight size={14} /></Link>
          </div>

          <div className={styles.askVisual}>
            <div className={styles.askBar}><Search size={17} /><span>Where are the 608 bearings?</span></div>
            <div className={styles.askResult}>
              <div className={styles.askResultIcon}><MapPin size={20} /></div>
              <div><small>34 in stock</small><strong>Machine shop · Drawer A04</strong><span>Updated from your shared inventory</span></div>
            </div>
            <div className={styles.resultMeta}>
              <span>608 bearing</span><span>Part #608-ZZ</span><span>Team visible</span>
            </div>
          </div>
        </section>

        <section className={styles.finalCta}>
          <div><h2>Make your inventory useful.</h2><p>Start with one photo, scan, or spreadsheet.</p></div>
          <Link href="/signup" className={styles.primaryButton}>Start free <ArrowRight size={15} /></Link>
        </section>
      </main>

      <MarketingFooter theme="light" />
    </div>
  );
}
