"use client";

import { useEffect, useState } from "react";

import { SiteNav } from "@/components/site/nav";

export function MarketingNav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 8);
    }

    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div
      className={
        "sticky top-0 z-50 transition-all " +
        (scrolled ? "backdrop-blur border-b bg-background/80" : "border-b bg-transparent")
      }
    >
      <SiteNav variant="marketing" />
    </div>
  );
}
