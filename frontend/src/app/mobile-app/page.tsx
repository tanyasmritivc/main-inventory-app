import {HeaderMarkup, FooterMarkup} from "@/components/marketing-dark/public-chrome";
import type { Metadata } from "next";
import { ArrowRight, Barcode, Camera, PackageSearch } from "lucide-react";
import { FindEZMark } from "@/components/site/findez-brand";

export const metadata: Metadata = {
  title: "Get the FindEZ AI app",
  description: "Take your physical memory with you. Scan your things, save their locations in Spaces, and ask FindEZ AI about them on iPhone.",
  robots: { index: false, follow: false },
};

const APP_STORE_URL = "https://apps.apple.com/us/app/findez-ai/id6760401697";

export default function MobileAppPage() {
  return (
    <><HeaderMarkup reserveSpace/><main className="mobile-app-page">
      <section className="mobile-app-content">
        <div className="mobile-app-copy">
          <span className="landing-kicker">FindEZ for iPhone</span>
          <h1>A memory for your things, wherever you are.</h1>
          <p>Take a photo, scan a barcode, save where things belong, and ask FindEZ AI what you have and where it is.</p>
          <a href={APP_STORE_URL}>Open or download FindEZ <ArrowRight size={15} /></a>
          <div><span><Camera size={14} /> Photo capture</span><span><Barcode size={14} /> Barcode lookup</span><span><PackageSearch size={14} /> Inventory search</span></div>
        </div>
        <div className="mobile-app-graphic" aria-label="FindEZ mobile app preview">
          <div className="mobile-orbit one" /><div className="mobile-orbit two" />
          <div className="phone-frame">
            <div className="phone-speaker" />
            <div className="phone-screen">
              <header><FindEZMark className="findez-logo small" width={21} height={21} /><b>Scan &amp; import</b></header>
              <div className="phone-scan"><span /><span /><span /><span /><Barcode size={58} strokeWidth={1} /><i /></div>
              <strong>Barcode detected</strong><small>M8 flange bolt · Cabinet B12</small>
              <button>Add to inventory</button>
            </div>
          </div>
        </div>
      </section>
    </main><FooterMarkup/></>
  );
}
