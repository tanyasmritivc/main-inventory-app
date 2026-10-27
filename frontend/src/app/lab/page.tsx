import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { LandingLab } from "@/components/site/landing-lab";

const geist = Geist({ subsets: ["latin"], weight: ["400", "500"], variable: "--fzl-geist", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--fzl-mono", display: "swap" });
export const metadata: Metadata = {
  title: "Lab preview",
  robots: { index: false, follow: false },
  alternates: { canonical: "/lab" },
};
export default function LabPage() {
  return <LandingLab className={`${geist.variable} ${mono.variable}`} />;
}
