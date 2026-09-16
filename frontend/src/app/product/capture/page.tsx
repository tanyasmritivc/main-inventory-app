import type { Metadata } from "next";
import Image from "next/image";
import { Barcode, Camera, Check, FileSpreadsheet, MapPin, MousePointer2, Search } from "lucide-react";

import { ProductDetailCta, ProductDetailHero, ProductDetailShell, productDetailStyles as detail } from "@/components/site/product-detail";

import visual from "../product-visuals.module.css";

export const metadata: Metadata = { title: "Capture Items", description: "Add FindEZ inventory from photos, barcodes, spreadsheets, or manual entry, with review before saving." };

const methods = [
  { title: "Photo", body: "Photograph a shelf or bin and review the visible items together.", icon: Camera },
  { title: "Barcode", body: "Scan one product code when you need a quick, exact lookup.", icon: Barcode },
  { title: "Spreadsheet", body: "Bring in an existing list without rebuilding every record.", icon: FileSpreadsheet },
  { title: "Manual entry", body: "Add or correct an item directly when you already know the details.", icon: MousePointer2 },
];

function CaptureDemo() {
  return (
    <div className={visual.window}>
      <div className={visual.windowBar}><span><Camera size={14} /> Photo review</span><b>10 detected</b></div>
      <div className={visual.captureBody}>
        <div className={visual.captureImage}>
          <Image src="/images/findez-parts-bin.jpg" alt="Workshop parts being reviewed before import" fill priority sizes="(max-width: 900px) 80vw, 520px" />
          <span className={visual.scanLine} />
          <span className={`${visual.detection} ${visual.detectionOne}`}><i>608 bearing</i></span>
          <span className={`${visual.detection} ${visual.detectionTwo}`}><i>M8 bolt</i></span>
          <span className={`${visual.detection} ${visual.detectionThree}`}><i>XT60</i></span>
        </div>
        <div className={visual.detectedPanel}>
          <header><span>Ready to add</span><b>Review</b></header>
          <div><Check size={13} /><strong>608 bearing</strong><span>×2</span></div>
          <div><Check size={13} /><strong>M8 bolt</strong><span>×7</span></div>
          <div><Check size={13} /><strong>XT60 connector</strong><span>×1</span></div>
        </div>
      </div>
    </div>
  );
}

export default function CapturePage() {
  return (
    <ProductDetailShell>
      <ProductDetailHero
        label="Capture inventory"
        title="Add inventory without starting over."
        description="Use one photo for a group, a barcode for one product, or a spreadsheet for an existing catalog. Review every result before saving."
        visual={<CaptureDemo />}
      />

      <section className={detail.contentSection}>
        <div className={detail.sectionHeader}><span>Choose the right input</span><h2>Use what is fastest for the job.</h2><p>Every method creates the same FindEZ item record, so your inventory stays consistent after it is added.</p></div>
        <div className={visual.methodList}>
          {methods.map((method) => { const Icon = method.icon; return <article className={visual.method} key={method.title}><span className={visual.methodIcon}><Icon size={18} /></span><h3>{method.title}</h3><p>{method.body}</p></article>; })}
        </div>
      </section>

      <section className={detail.greenSection}>
        <div className={detail.greenInner}>
          <div className={detail.greenCopy}><span>Before anything is saved</span><h2>Review, place, then find.</h2><p>Confirm the item details, choose the Space where the items live, and save them to the inventory your team already searches.</p></div>
          <div className={visual.reviewFlow}>
            <div className={visual.reviewStep}><span><Check size={17} /></span><strong>Review details</strong><small>Correct names and quantities before import.</small></div>
            <div className={visual.reviewStep}><span><MapPin size={17} /></span><strong>Choose a Space</strong><small>Save the item where it physically belongs.</small></div>
            <div className={visual.reviewStep}><span><Search size={17} /></span><strong>Search later</strong><small>Find the same record by item or location.</small></div>
          </div>
        </div>
      </section>

      <ProductDetailCta title="Start with what is in front of you." body="Add your first item from a photo, code, or file." />
    </ProductDetailShell>
  );
}
