import { Geist, Geist_Mono } from "next/font/google";
import { previewPrompt } from "@/lib/landing-preview";
import { requireUser } from "@/lib/auth-guard";
import { WebOnboarding } from "@/components/site/onboarding/web-onboarding";

const geist = Geist({ subsets: ["latin"], weight: ["400", "500", "600"], variable: "--font-onboarding", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: "500", variable: "--font-onboarding-mono", display: "swap" });
export const metadata = { title: "Build your world", robots: { index: false, follow: false } };

export default async function OnboardingPage({ searchParams }: { searchParams: Promise<{ prompt?: string }> }) {
  const prompt = previewPrompt((await searchParams).prompt);
  const user = await requireUser(`/onboarding${prompt ? `?${new URLSearchParams({ prompt })}` : ""}`);
  return <div className={`${geist.variable} ${mono.variable}`}><WebOnboarding userId={user.id} initialPrompt={prompt} /></div>;
}
