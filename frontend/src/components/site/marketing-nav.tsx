import { SiteNav } from "@/components/site/nav";

export function MarketingNav({ theme = "dark" }: { theme?: "light" | "dark" }) {
  return (
    <div className="marketing-nav-wrap sticky top-0 z-50">
      <SiteNav variant="marketing" theme={theme} />
    </div>
  );
}
