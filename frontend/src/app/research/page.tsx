import type { Metadata } from "next";
import { PagesShell } from "@/components/pages-ui/PagesShell";
import { BlurText, HeroBackdrop, GradientCard } from "@/components/pages-ui/cards";
import { FIND_RESEARCH as research } from "@/lib/find-research";

export const metadata: Metadata = {
  title: "Research",
  description: research.description,
  alternates: { canonical: "/research" },
};

export default function ResearchPage() {
  return (
    <PagesShell page="research">
      <main>
        <header className="public-intro">
          <HeroBackdrop />
          <h1><BlurText>Building FIND</BlurText></h1>
          <div className="public-actions">
            <a className="public-primary" href={research.contactHref}>{research.contactLabel}</a>
          </div>
        </header>
        <div className="pages-column">
          <section className="public-section">
            <p className="research-intro-copy" data-scroll-words>
              {research.introduction.split(/(\s+)/).map((word, i) => <span key={i}>{word}</span>)}
            </p>
          </section>
          <section className="public-section">
            <GradientCard tone="ember" className="research-road">
              <h2>{research.heading[0]}<br />{research.heading[1]}</h2>
              <div className="research-labels">
                {research.labels.map(label => <span key={label}>{label}</span>)}
              </div>
              <div className="research-pillars">
                {research.pillars.map(([label, title, detail], i) => (
                  <article key={title}>
                    <em className={i === 0 ? "current-dot" : undefined}>{label}</em>
                    <h3>{title}</h3>
                    <p>{detail}</p>
                  </article>
                ))}
              </div>
            </GradientCard>
            <p className="public-note">{research.status}</p>
            <p className="public-note">{research.invitation}</p>
          </section>
        </div>
      </main>
    </PagesShell>
  );
}
