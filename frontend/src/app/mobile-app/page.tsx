import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Barcode, Camera, PackageSearch } from "lucide-react";

export const metadata: Metadata = {
  title: "Get the FindEZ app",
  description: "Use the FindEZ iOS app for inventory, sharing, scanning, and AI tools.",
  robots: { index: false, follow: false },
};

const APP_STORE_URL = "https://apps.apple.com/app/findez/id6746827458";

export default function MobileAppPage() {
  return (
    <main className="mobile-app-page">
      <nav>
        <Link href="/" className="landing-wordmark"><Image className="findez-logo" src="/images/findez-logo.png" alt="" width={28} height={28} priority /><span>FindEZ</span></Link>
        <Link href="/docs/api">Developers</Link>
      </nav>
      <section className="mobile-app-content">
        <div className="mobile-app-copy">
          <span className="landing-kicker">FindEZ for iPhone</span>
          <h1>Your inventory goes where the work happens.</h1>
          <p>Capture a shelf, scan a barcode, check a location, or ask FindEZ from the workshop floor.</p>
          <a href={APP_STORE_URL}>Open or download FindEZ <ArrowRight size={15} /></a>
          <div><span><Camera size={14} /> Photo capture</span><span><Barcode size={14} /> Barcode lookup</span><span><PackageSearch size={14} /> Inventory search</span></div>
        </div>
        <div className="mobile-app-graphic" aria-label="FindEZ mobile app preview">
          <div className="mobile-orbit one" /><div className="mobile-orbit two" />
          <div className="phone-frame">
            <div className="phone-speaker" />
            <div className="phone-screen">
              <header><Image className="findez-logo small" src="/images/findez-logo.png" alt="" width={21} height={21} /><b>Scan &amp; import</b></header>
              <div className="phone-scan"><span /><span /><span /><span /><Barcode size={58} strokeWidth={1} /><i /></div>
              <strong>Barcode detected</strong><small>M8 flange bolt · Cabinet B12</small>
              <button>Add to inventory</button>
            </div>
          </div>
        </div>
      </section>
      <footer><span>© {new Date().getFullYear()} AI Robots Inc.</span><div><Link href="/settings">Manage account</Link><Link href="/privacy">Privacy</Link><Link href="/">Website</Link></div></footer>
    </main>
  );
}
