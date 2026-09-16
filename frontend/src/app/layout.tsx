import type { Metadata } from "next";
import { DM_Sans, Inter, Syne } from "next/font/google";
import { AppDialogProvider } from "@/components/site/app-dialog-provider";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
  axes: ["opsz"],
});

const syne = Syne({
  subsets: ["latin"],
  variable: "--font-syne",
  weight: ["400", "600", "700", "800"],
  display: "swap",
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://findez.ai"),
  title: {
    default: "FindEZ — Intelligent inventory for the real world",
    template: "%s | FindEZ",
  },
  description: "Capture items from photos, barcodes, or spreadsheets, then find anything through search or Ask FindEZ.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "FindEZ",
    description: "Know what you have. Find it.",
    url: "https://findez.ai",
    siteName: "FindEZ",
    type: "website",
  },
  icons: {
    icon: "/images/findez-logo.png",
    apple: "/images/findez-logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`dark ${inter.variable} ${syne.variable} ${dmSans.variable}`}>
      <head>
        <meta name="theme-color" content="#f3f4f0" />
      </head>
      <body className={`${inter.className} antialiased`}>
        <AppDialogProvider><div style={{ minHeight: '100dvh' }}>{children}</div></AppDialogProvider>
      </body>
    </html>
  );
}
