import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";
import { Button } from "@/components/ui/button";

export default function Home() {
  return (
    <div className="min-h-screen bg-background flex flex-col">
      <div className="relative flex flex-col flex-1">
        <MarketingNav />

        <main className="mx-auto w-full max-w-5xl px-4 py-20 md:py-28 flex flex-col flex-1">
          <section className="mx-auto w-full max-w-[640px] text-center space-y-7 animate-fade-up">
            <h1 className="text-[44px] font-semibold tracking-[-0.02em] leading-[1.1] text-white sm:text-[56px]">
              AI that remembers<br className="hidden sm:block" /> everything you own.
            </h1>
            <p className="text-[18px] text-white/55 max-w-[440px] mx-auto leading-relaxed">
              Scan anything. Ask anything. Never buy something you already have.
            </p>
            <div className="flex flex-col gap-3 sm:flex-row sm:justify-center">
              <Button asChild size="lg">
                <Link href="/signup">Get Started free</Link>
              </Button>
              <Button asChild variant="outline" size="lg">
                <Link href="/signin">Sign In</Link>
              </Button>
            </div>
            <p className="text-xs text-white/30">Free · No credit card required</p>
          </section>

          <section className="mt-20 animate-fade-up" style={{ animationDelay: "120ms" }}>
            <div className="grid gap-4 sm:grid-cols-3">
              <div className="rounded-[20px] border border-white/[0.10] bg-white/[0.05] p-6 backdrop-blur-xl">
                <div className="mb-3 text-white/50">
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
                </div>
                <div className="text-[15px] font-semibold text-white">Stop buying duplicates</div>
                <div className="mt-1.5 text-[13px] text-white/50 leading-relaxed">Know what you already have before you spend.</div>
              </div>
              <div className="rounded-[20px] border border-white/[0.10] bg-white/[0.05] p-6 backdrop-blur-xl">
                <div className="mb-3 text-white/50">
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m13 2 3 3-3 3"/><path d="M2 13h13"/><path d="m13 22-3-3 3-3"/><path d="M22 11H9"/></svg>
                </div>
                <div className="text-[15px] font-semibold text-white">Find things instantly</div>
                <div className="mt-1.5 text-[13px] text-white/50 leading-relaxed">Search across everything you own in seconds.</div>
              </div>
              <div className="rounded-[20px] border border-white/[0.10] bg-white/[0.05] p-6 backdrop-blur-xl">
                <div className="mb-3 text-white/50">
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2"/><path d="M20 14h2"/><path d="M15 13v2"/><path d="M9 13v2"/></svg>
                </div>
                <div className="text-[15px] font-semibold text-white">Let AI do the checking</div>
                <div className="mt-1.5 text-[13px] text-white/50 leading-relaxed">FindEZ surfaces overlaps and similarities for you.</div>
              </div>
            </div>
          </section>

          {false && false && <style>{`
            .findez-example {
              position: absolute;
              left: 0;
              top: 0;
              opacity: 0;
              visibility: hidden;
              transform: none;
              display: inline-block;
            }

            .findez-demo-rows {
              height: 132px;
            }

            .findez-example-1 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType1 17.5s steps(11, end) infinite;
            }

            .findez-example-2 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType2 17.5s steps(13, end) infinite;
            }

            .findez-example-3 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType3 17.5s steps(11, end) infinite;
            }

            .findez-example-4 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType4 17.5s steps(10, end) infinite;
            }

            .findez-example-5 {
              width: 0;
              white-space: nowrap;
              overflow: hidden;
              animation: findezType5 17.5s steps(8, end) infinite;
            }

            .findez-frame {
              position: absolute;
              left: 0;
              right: 0;
              top: 0;
              opacity: 0;
              visibility: hidden;
              transform: none;
              pointer-events: none;
            }

            .findez-frame-1 {
              animation: findezResults1 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-2 {
              animation: findezResults2 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-3 {
              animation: findezResults3 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-4 {
              animation: findezResults4 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-frame-5 {
              animation: findezResults5 17.5s cubic-bezier(0.16, 1, 0.3, 1) infinite;
            }

            .findez-checkline {
              opacity: 0.9;
            }

            @keyframes findezType1 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              6.857% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              11.143% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              22.8% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              24.343% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType2 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              25.486% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              26.343% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              30.629% {
                opacity: 1;
                visibility: visible;
                width: 13ch;
              }
              41.429% {
                opacity: 1;
                visibility: visible;
                width: 13ch;
              }
              42.971% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType3 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              44.114% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              44.971% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              49.257% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              60.057% {
                opacity: 1;
                visibility: visible;
                width: 11ch;
              }
              61.6% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType4 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              62.743% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              63.6% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              67.886% {
                opacity: 1;
                visibility: visible;
                width: 10ch;
              }
              78.686% {
                opacity: 1;
                visibility: visible;
                width: 10ch;
              }
              80.229% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezType5 {
              0% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              81.371% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              82.229% {
                opacity: 1;
                visibility: visible;
                width: 0;
              }
              86.514% {
                opacity: 1;
                visibility: visible;
                width: 8ch;
              }
              97.314% {
                opacity: 1;
                visibility: visible;
                width: 8ch;
              }
              98.857% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
              100% {
                opacity: 0;
                visibility: hidden;
                width: 0;
              }
            }

            @keyframes findezResults1 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              14.0% {
                opacity: 0;
                visibility: hidden;
              }
              14.571% {
                opacity: 1;
                visibility: visible;
              }
              23.657% {
                opacity: 1;
                visibility: visible;
              }
              24.343% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults2 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              32.0% {
                opacity: 0;
                visibility: hidden;
              }
              33.2% {
                opacity: 1;
                visibility: visible;
              }
              42.286% {
                opacity: 1;
                visibility: visible;
              }
              42.971% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults3 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              50.629% {
                opacity: 0;
                visibility: hidden;
              }
              51.829% {
                opacity: 1;
                visibility: visible;
              }
              60.914% {
                opacity: 1;
                visibility: visible;
              }
              61.6% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults4 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              69.257% {
                opacity: 0;
                visibility: hidden;
              }
              70.457% {
                opacity: 1;
                visibility: visible;
              }
              79.543% {
                opacity: 1;
                visibility: visible;
              }
              80.229% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @keyframes findezResults5 {
              0% {
                opacity: 0;
                visibility: hidden;
              }
              87.886% {
                opacity: 0;
                visibility: hidden;
              }
              89.086% {
                opacity: 1;
                visibility: visible;
              }
              98.171% {
                opacity: 1;
                visibility: visible;
              }
              98.857% {
                opacity: 0;
                visibility: hidden;
              }
              100% {
                opacity: 0;
                visibility: hidden;
              }
            }

            @media (prefers-reduced-motion: reduce) {
              .findez-example,
              .findez-frame {
                animation: none !important;
              }
              .findez-example {
                position: static;
                opacity: 0;
                visibility: hidden;
                width: auto;
              }
              .findez-example-1 {
                opacity: 1;
                visibility: visible;
                width: auto;
              }
              .findez-frame {
                position: static;
                opacity: 0;
                visibility: hidden;
                transform: none;
              }
              .findez-frame-1 {
                opacity: 1;
                visibility: visible;
              }
            }
          `}</style>}

          <footer className="mt-auto border-t border-white/[0.08] py-10 text-center text-xs text-white/20">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap items-center justify-center gap-3">
                <Link href="/privacy" className="hover:underline">
                  Privacy Policy
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms of Service
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms & Conditions
                </Link>
                © 2026 FindEZ. All rights reserved.
              </div>
              <div>Built with care. Tiny credit: UI-inspired by modern AI product dashboards.</div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
