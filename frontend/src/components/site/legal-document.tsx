import Link from "next/link";
import { legalPublication, type LegalSection } from "@/lib/legal-content";
import { LegalPrintButton } from "./legal-print-button";
import styles from "./legal-document.module.css";

type Props = {
  kind: "privacy" | "terms";
  title: string;
  intro: string;
  sections: LegalSection[];
};

function Contents({ sections }: { sections: LegalSection[] }) {
  return <ol>{sections.map((section) => (
    <li key={section.id}><a href={`#${section.id}`}>{section.heading.replace(/^\d+\. /, "")}</a></li>
  ))}</ol>;
}

export function LegalDocument({ kind, title, intro, sections }: Props) {
  return (
    <div className={styles.page}>
      <a className={styles.skip} href="#legal-content">Skip to {title}</a>
      <header className={styles.header}>
        <Link href="/" aria-label="FindEZ home" className={styles.brand}>
          {/* Supplied outlined artwork, not a live-text recreation. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/findez-legal-wordmark.svg" alt="FindEZ" width={146} height={48} />
        </Link>
        <nav aria-label="Legal pages">
          <Link href="/privacy" aria-current={kind === "privacy" ? "page" : undefined}>Privacy</Link>
          <Link href="/terms" aria-current={kind === "terms" ? "page" : undefined}>Terms</Link>
          <a href="mailto:info@findez.ai">Contact</a>
        </nav>
      </header>

      <main id="legal-content" className={styles.main} tabIndex={-1}>
        <div className={styles.review} role="note" aria-label="Review draft notice">
          <strong>Review draft - not yet effective</strong>
          <p>This revision is awaiting data-practice confirmation and legal review. It has not replaced the published policies. Items marked "REVIEW REQUIRED" must be resolved before publication.</p>
          <a href={`https://www.findez.ai/${kind}`}>View the currently published {title.toLowerCase()}</a>
        </div>

        <div className={styles.intro}>
          <p className={styles.eyebrow}>FindEZ / Legal</p>
          <h1>{title}</h1>
          <p className={styles.date}>Draft revised <time dateTime={legalPublication.revisedISO}>{legalPublication.revised}</time></p>
          <p>{intro}</p>
          <div className={styles.tools}>
            <a href="mailto:info@findez.ai">info@findez.ai</a>
            <LegalPrintButton />
          </div>
        </div>

        <div className={styles.document}>
          <nav className={styles.contents} aria-label="On this page">
            <h2>On this page</h2>
            <Contents sections={sections} />
          </nav>
          <details className={styles.mobileContents}>
            <summary>On this page</summary>
            <nav aria-label="Section navigation"><Contents sections={sections} /></nav>
          </details>
          <article className={styles.article} aria-label={title}>
            {sections.map((section) => (
              <section key={section.id} id={section.id} aria-labelledby={`${section.id}-heading`} className={section.emphasized ? styles.emphasized : undefined}>
                <h2 id={`${section.id}-heading`}>{section.heading}</h2>
                {section.body.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
                {section.bullets && <ul>{section.bullets.map((bullet) => <li key={bullet}>{bullet}</li>)}</ul>}
                {section.links && <div className={styles.sectionLinks}>{section.links.map((link) => <a key={link.href} href={link.href}>{link.label}</a>)}</div>}
              </section>
            ))}
            <a href="#legal-content" className={styles.backToTop}>Back to top</a>
          </article>
        </div>
      </main>

      <footer className={styles.footer}>
        <span>AI Robots Inc / FindEZ</span>
        <nav aria-label="Legal footer">
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/terms">Terms of Service</Link>
          <Link href="/">Home</Link>
        </nav>
      </footer>
    </div>
  );
}
