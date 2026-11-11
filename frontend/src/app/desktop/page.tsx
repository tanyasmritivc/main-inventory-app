import type { Metadata } from "next";
import Link from "next/link";
import styles from "./desktop.module.css";

export const metadata: Metadata = {
  title: "Download FindEZ for Mac and Windows",
  description: "Your inventory, Ask and CAD Intelligence in the FindEZ desktop app.",
};

const downloads = [
  { title: "Mac · Apple silicon", detail: "For Macs with an M-series chip", file: "FindEZ-0.1.2-mac-arm64.dmg" },
  { title: "Mac · Intel", detail: "For Macs with an Intel processor", file: "FindEZ-0.1.2-mac-x64.dmg" },
  { title: "Windows", detail: "Windows 10 or later · 64-bit Intel / AMD", file: "FindEZ-0.1.2-win-x64.exe" },
];

export default function DesktopPage() {
  return <main className={styles.page}>
    <nav className={styles.nav}><Link href="/" className={styles.brand}>FindEZ</Link><a href="/worlds">Open in browser ↗</a></nav>
    <section className={styles.hero}>
      <span className={styles.eyebrow}>FINDEZ FOR DESKTOP · PREVIEW 0.1.2</span>
      <h1>Your world.<br />One app away.</h1>
      <p>Your inventory, Ask and CAD Intelligence, together on your desktop. Sign in with your existing FindEZ account.</p>
    </section>
    <section className={styles.downloads} aria-label="Download FindEZ">
      {downloads.map(item => <article className={styles.card} key={item.file}>
        <h2>{item.title}</h2><p>{item.detail}</p>
        <a className={styles.button} href={`/downloads/desktop/${item.file}`} download>Download <span aria-hidden>↓</span></a>
      </article>)}
    </section>
    <section className={styles.details}>
      <div><h2>Made for your workflow</h2><p>Upload photos and BOM files, compare your Fusion designs with inventory, and keep FindEZ in its own window. Your data stays connected to the same FindEZ service.</p></div>
      <div><h2>Install and sign in</h2><p>On Mac, open the DMG and drag FindEZ into Applications. On Windows, run the installer. Internet access is required. Google and Apple sign-in open in your browser and return to the app.</p></div>
      <div className={styles.notice}><h2>Early desktop preview</h2><p>The Mac apps are Developer ID signed and notarized by Apple. Mac requires macOS 13 or later. The Windows preview is unsigned and may trigger a security warning; use the browser version if your computer requires signed apps. Windows installation and hardware features still need testing on a Windows computer.</p><p>Web features update through FindEZ; desktop installer updates are manual through this page.</p><a href="/downloads/desktop/SHA256SUMS.txt">Download checksums</a></div>
    </section>
    <footer className={styles.footer}><a href="/privacy">Privacy</a><a href="/terms">Terms</a><span>© 2026 AI Robots Inc.</span></footer>
  </main>;
}
