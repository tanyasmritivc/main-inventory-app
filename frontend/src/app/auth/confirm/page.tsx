import type { Metadata } from "next";
import { EmailConfirmClient } from "@/components/site/email-confirm-client";
import "./confirm.css";

export const metadata: Metadata = {
  title: "Confirm email",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export default function EmailConfirmPage() { return <EmailConfirmClient />; }
