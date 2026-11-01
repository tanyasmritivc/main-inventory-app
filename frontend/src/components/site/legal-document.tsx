import type { ReactNode } from "react";
import styles from "./legal-document.module.css";

export type LegalSection = { id?: string; heading: string; body: string[]; bullets?: string[]; emphasized?: boolean };
export function LegalDocument({ title, effective, intro, sections, footer }: {
  title: string; effective: string; intro: string; sections: LegalSection[]; footer: ReactNode;
}) {
  return <main className={styles.document}>
    <article>
      <header className={styles.intro}><h1>{title}</h1><p className={styles.date}>Effective {effective}</p><p>{intro}</p></header>
      <nav className={styles.contents} aria-label={`${title} contents`}>
        {sections.map((section, index) => <a key={section.heading} href={`#${section.id || `section-${index + 1}`}`}>{section.heading.replace(/^\d+\.\s*/, "")}</a>)}
      </nav>
      {sections.map((section, index) => <section key={section.heading} id={section.id || `section-${index + 1}`} className={styles.section}>
        <h2>{section.heading}</h2>
        {section.body.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
        {section.bullets && <ul>{section.bullets.map((bullet) => <li key={bullet}>{bullet}</li>)}</ul>}
      </section>)}
    </article>
    <footer className={styles.footer}>{footer}</footer>
  </main>;
}
