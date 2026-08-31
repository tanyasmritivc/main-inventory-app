import type { ReactNode } from "react";

export function LegalDocument({ title, effective, intro, sections, footer }: {
  title: string;
  effective: string;
  intro: string;
  sections: { heading: string; body: string[]; bullets?: string[]; emphasized?: boolean }[];
  footer: ReactNode;
}) {
  return (
    <main className="mx-auto w-full max-w-3xl px-5 py-14 flex-1">
      <article className="space-y-8 text-sm leading-7 text-foreground/90">
        <header className="space-y-3">
          <h1 className="text-3xl font-semibold tracking-tight text-foreground">{title}</h1>
          <p className="text-muted-foreground">Effective: {effective}</p>
          <p>{intro}</p>
        </header>
        {sections.map((section) => (
          <section key={section.heading} className="space-y-3">
            <h2 className="text-lg font-semibold tracking-tight text-foreground">{section.heading}</h2>
            {section.body.map((paragraph) => (
              <p key={paragraph} className={section.emphasized ? "font-medium" : undefined}>{paragraph}</p>
            ))}
            {section.bullets && <ul className="list-disc space-y-2 pl-5">
              {section.bullets.map((bullet) => <li key={bullet}>{bullet}</li>)}
            </ul>}
          </section>
        ))}
      </article>
      <footer className="mt-12 flex flex-wrap items-center gap-3 border-t pt-6 text-xs text-muted-foreground">{footer}</footer>
    </main>
  );
}
