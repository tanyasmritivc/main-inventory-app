import { HeaderMarkup } from "@/components/marketing-dark/public-chrome";
export function MarketingNav(_props: {theme?: "light" | "dark"} = {}) {
  void _props; // Legacy callers may pass a theme; public chrome matches the homepage.
  return <HeaderMarkup reserveSpace/>;
}
