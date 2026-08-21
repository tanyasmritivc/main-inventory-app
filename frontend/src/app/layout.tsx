import type { Metadata } from "next";
import { DM_Sans, Inter, Syne } from "next/font/google";
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
    default: "FindEZ AI | Your workshop inventory assistant",
    template: "%s | FindEZ AI",
  },
  description: "Find, organize, and share your workshop inventory with FindEZ AI.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "FindEZ AI",
    description: "Your workshop inventory assistant.",
    url: "https://findez.ai",
    siteName: "FindEZ AI",
    type: "website",
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
        <meta name="theme-color" content="#0a0a0a" />
      </head>
      <body className={`${inter.className} antialiased`}>
        <div className="min-h-dvh">{children}</div>
      </body>
    </html>
  );
}
