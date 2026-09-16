import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowRight,
  Barcode,
  Box,
  Camera,
  Check,
  ChevronRight,
  FileSpreadsheet,
  MapPin,
  Search,
  Sparkles,
  Users,
} from "lucide-react";

import { MarketingFooter } from "@/components/site/product-marketing";
import { MarketingNav } from "@/components/site/marketing-nav";

import styles from "./home.module.css";

export const metadata: Metadata = {
  title: { absolute: "FindEZ — Know what you have. Find it when you need it." },
  description: "Turn photos, barcodes, and spreadsheets into searchable physical inventory with FindEZ.",
};

const detections = [
  { label: "608 bearing", className: styles.detectBearing },
  { label: "M4 bolts", className: styles.detectBolts },
  { label: "XT60", className: styles.detectConnector },
  { label: "bracket", className: styles.detectBracket },
];

export default function LandingPage() {
  return (
    <div className={styles.page}>
      <MarketingNav />

      <main>
        <section className={styles.hero}>
          <div className={styles.heroCopy}>
            <p className={styles.overline}>AI inventory for the physical world</p>
            <h1>
              Know what you have.
              <span>Find it when you need it.</span>
            </h1>
          </div>

          <div className={styles.heroIntro}>
            <p>
              Photograph a bin, scan a barcode, or import a spreadsheet. FindEZ
              turns physical things into searchable inventory.
            </p>
            <div className={styles.heroActions}>
              <Link href="/signup" className={styles.primaryButton}>
                Start free <ArrowRight size={14} />
              </Link>
              <a href="#how-it-works" className={styles.secondaryButton}>
                See how it works
              </a>
            </div>
            <p className={styles.freeNote}>
              <Check size={13} /> Free to use while FindEZ is in early access.
            </p>
          </div>
        </section>

        <section id="how-it-works" className={styles.productSection}>
          <header className={styles.sectionHeader}>
            <div>
              <p className={styles.overline}>From the room to the record</p>
              <h2>Physical inventory, finally searchable.</h2>
            </div>
            <p>
              FindEZ brings capture, organization, and retrieval into one calm
              system built around where things actually live.
            </p>
          </header>

          <div className={styles.featureGrid}>
            <article className={`${styles.featureCard} ${styles.captureCard}`}>
              <div className={styles.cardCopy}>
                <span className={styles.cardIcon}><Camera size={16} /></span>
                <h3>Turn a photo into inventory.</h3>
                <p>FindEZ identifies the items in a bin or on a shelf so you can review and save them.</p>
                <Link href="/product/capture">Explore capture <ChevronRight size={13} /></Link>
              </div>

              <div className={styles.captureVisual} aria-label="A sample parts photo with four detected objects">
                <div className={styles.captureToolbar}>
                  <span><span className={styles.liveDot} /> Workshop bin.jpg</span>
                  <b>4 items found</b>
                </div>
                <div className={styles.partsSurface}>
                  <div className={styles.binGrid} aria-hidden="true" />
                  {detections.map((detection) => (
                    <span key={detection.label} className={`${styles.detection} ${detection.className}`}>
                      <i>{detection.label}</i>
                    </span>
                  ))}
                  <span className={styles.partBearing} aria-hidden="true" />
                  <span className={styles.partBolts} aria-hidden="true">•••</span>
                  <span className={styles.partConnector} aria-hidden="true" />
                  <span className={styles.partBracket} aria-hidden="true" />
                </div>
              </div>
            </article>

            <article className={`${styles.featureCard} ${styles.askCard}`}>
              <div className={styles.cardCopy}>
                <span className={styles.cardIcon}><Sparkles size={16} /></span>
                <h3>Ask instead of digging.</h3>
                <p>Use ordinary language to find an item and its exact location.</p>
              </div>
              <div className={styles.askVisual}>
                <div className={styles.askInput}>
                  <Search size={14} />
                  <span>Where are the 608 bearings?</span>
                </div>
                <div className={styles.askAnswer}>
                  <span className={styles.answerIcon}><MapPin size={15} /></span>
                  <div>
                    <small>Best match · 34 in stock</small>
                    <strong>Machine shop</strong>
                    <span>Drawer A04</span>
                  </div>
                </div>
              </div>
            </article>

            <article className={`${styles.featureCard} ${styles.spacesCard}`}>
              <div className={styles.cardCopy}>
                <span className={styles.cardIcon}><Box size={16} /></span>
                <h3>Mirror your real spaces.</h3>
                <p>Keep every item tied to the room, cabinet, shelf, or bin where it belongs.</p>
                <Link href="/product/spaces-and-sharing">Explore Spaces <ChevronRight size={13} /></Link>
              </div>
              <div className={styles.spaceTree} aria-label="Example inventory location hierarchy">
                <div className={styles.rootNode}><Box size={15} /><span>Machine shop</span><b>312 items</b></div>
                <span className={styles.treeLine} aria-hidden="true" />
                <div className={styles.childNodes}>
                  <div><span><span className={styles.nodeDot} /> Fastener cabinet</span><b>186</b></div>
                  <div><span><span className={styles.nodeDot} /> Electronics shelf</span><b>78</b></div>
                  <div><span><span className={styles.nodeDot} /> Tool chest</span><b>48</b></div>
                </div>
              </div>
            </article>

            <article className={`${styles.featureCard} ${styles.importCard}`}>
              <div className={styles.cardCopy}>
                <span className={styles.cardIcon}><Users size={16} /></span>
                <h3>One inventory, however it comes in.</h3>
                <p>Start with the information you already have. Your team sees the same live inventory.</p>
              </div>
              <div className={styles.importMethods}>
                <div><Camera size={17} /><span>Photos</span><b>AI review</b></div>
                <div><Barcode size={17} /><span>Barcodes</span><b>Quick lookup</b></div>
                <div><FileSpreadsheet size={17} /><span>Spreadsheets</span><b>Bulk import</b></div>
              </div>
            </article>
          </div>
        </section>

        <section className={styles.closingSection}>
          <div>
            <p className={styles.overline}>Your things, remembered</p>
            <h2>Stop keeping inventory in your head.</h2>
          </div>
          <Link href="/signup" className={styles.primaryButton}>
            Start free <ArrowRight size={14} />
          </Link>
        </section>
      </main>

      <MarketingFooter />
    </div>
  );
}
