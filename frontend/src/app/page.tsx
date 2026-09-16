import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  Barcode,
  Box,
  Camera,
  Check,
  FileSpreadsheet,
  MapPin,
  Search,
  Sparkles,
} from "lucide-react";

import { MarketingFooter } from "@/components/site/product-marketing";
import { MarketingNav } from "@/components/site/marketing-nav";

import styles from "./home.module.css";

export const metadata: Metadata = {
  title: { absolute: "FindEZ — Know what you have. Find it." },
  description: "Turn photos, barcodes, and spreadsheets into inventory you can search.",
};

const detectedItems = [
  { name: "608 bearing", count: "2" },
  { name: "M8 bolt", count: "7" },
  { name: "XT60 connector", count: "1" },
];

export default function LandingPage() {
  return (
    <div className={styles.page}>
      <MarketingNav theme="light" />

      <main>
        <section className={styles.hero}>
          <div className={styles.heroCopy}>
            <h1>
              Know what you have.
              <span>Find it.</span>
            </h1>
            <p>Turn photos, scans, and spreadsheets into inventory you can search.</p>
            <div className={styles.heroActions}>
              <Link href="/signup" className={styles.primaryButton}>
                Start free <ArrowRight size={15} />
              </Link>
              <a href="#how-it-works" className={styles.textLink}>See it work</a>
            </div>
          </div>

          <div className={styles.heroVisual} aria-label="FindEZ identifying parts in a workshop bin">
            <div className={styles.visualHeader}>
              <span><Camera size={15} /> Photo import</span>
              <span className={styles.processing}><i /> Analyzing</span>
            </div>

            <div className={styles.photoFrame}>
              <Image
                src="/images/findez-parts-bin.jpg"
                alt="A green workshop bin containing bearings, bolts, wires, and a connector"
                fill
                priority
                sizes="(max-width: 860px) 82vw, 520px"
              />
              <span className={styles.scanLine} aria-hidden="true" />
              <span className={`${styles.detection} ${styles.bearingBox}`}><i>608 bearing</i></span>
              <span className={`${styles.detection} ${styles.boltBox}`}><i>M8 bolt</i></span>
              <span className={`${styles.detection} ${styles.connectorBox}`}><i>XT60</i></span>
            </div>

            <div className={styles.resultPanel}>
              <header>
                <span>Ready to add</span>
                <b>10 items</b>
              </header>
              {detectedItems.map((item) => (
                <div className={styles.resultRow} key={item.name}>
                  <span><Check size={12} /></span>
                  <strong>{item.name}</strong>
                  <b>×{item.count}</b>
                </div>
              ))}
              <footer><MapPin size={13} /> Machine shop</footer>
            </div>

            <div className={styles.savedPill}>
              <span><Check size={12} /></span>
              Inventory ready
            </div>
          </div>
        </section>

        <section id="how-it-works" className={styles.flowSection}>
          <div className={styles.sectionTitle}>
            <h2>Photo in. Location out.</h2>
          </div>

          <div className={styles.flowGraphic}>
            <article>
              <span className={styles.flowIcon}><Camera size={18} /></span>
              <div className={styles.flowPhoto}>
                <Image src="/images/findez-parts-bin.jpg" alt="" fill sizes="240px" />
              </div>
              <strong>Capture</strong>
            </article>

            <span className={styles.flowConnector} aria-hidden="true"><i /></span>

            <article>
              <span className={styles.flowIcon}><Sparkles size={18} /></span>
              <div className={styles.itemStack}>
                <span>608 bearing <b>2</b></span>
                <span>M8 bolt <b>7</b></span>
                <span>XT60 <b>1</b></span>
              </div>
              <strong>Understand</strong>
            </article>

            <span className={styles.flowConnector} aria-hidden="true"><i /></span>

            <article>
              <span className={styles.flowIcon}><MapPin size={18} /></span>
              <div className={styles.locationCard}>
                <span>Machine shop</span>
                <strong>Drawer A04</strong>
              </div>
              <strong>Place</strong>
            </article>
          </div>

          <div className={styles.inputRail} aria-label="Supported inventory inputs">
            <span><Camera size={15} /> Photos</span>
            <span><Barcode size={15} /> Barcodes</span>
            <span><FileSpreadsheet size={15} /> Spreadsheets</span>
          </div>
        </section>

        <section className={styles.askSection}>
          <div className={styles.askCopy}>
            <h2>Ask. Find. Done.</h2>
            <Link href="/product/ask">Meet Ask FindEZ <ArrowRight size={14} /></Link>
          </div>

          <div className={styles.askDemo}>
            <div className={styles.askInput}>
              <Search size={17} />
              <span>Where are the 608 bearings?</span>
            </div>
            <div className={styles.askAnswer}>
              <span><MapPin size={18} /></span>
              <div>
                <small>34 in stock</small>
                <strong>Machine shop · Drawer A04</strong>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.finalSection}>
          <div className={styles.finalMark} aria-hidden="true"><Box size={30} /></div>
          <h2>Your inventory, remembered.</h2>
          <Link href="/signup" className={styles.primaryButton}>
            Start free <ArrowRight size={15} />
          </Link>
        </section>
      </main>

      <MarketingFooter theme="light" />
    </div>
  );
}
