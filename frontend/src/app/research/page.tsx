import type { Metadata } from "next";
import { Header } from "@/components/landing-v5/Header";
import { Footer } from "@/components/landing-v5/Footer";
import { publicFonts } from "@/components/landing-v5/fonts";
import { ResearchContent } from "@/components/research/ResearchContent";
import { ResearchMotion } from "@/components/research/ResearchMotion";
import "@/components/landing-v5/landing.css";
import "@/components/pages-ui/pages.css";
import "@/components/research/research.css";

export const metadata: Metadata = {
 title: { absolute: "FIND Research | FindEZ AI" },
 description: "FindEZ AI's proprietary perception pipeline, combining specialized computer vision and intelligent recognition systems to identify physical inventory items with increasing precision. Currently in development.",
 alternates: { canonical: "/research" },
};

export default function ResearchPage() {
 return <div className={`research-shell ${publicFonts}`}>
  <div className="pages-ui" data-page="research"><div className="landing-v5 pages-header"><Header prefetch={false} /></div></div>
  <ResearchMotion><ResearchContent /></ResearchMotion>
  <div className="pages-ui" data-page="research"><div className="landing-v5 pages-footer"><Footer prefetch={false} /></div></div>
 </div>;
}
