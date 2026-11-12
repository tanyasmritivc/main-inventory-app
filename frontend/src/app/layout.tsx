import { Suspense } from "react";
import { AppThemeDocument } from "@/components/site/use-app-theme";
import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Geist_Mono, Inter, Inter_Tight } from "next/font/google";
import { AppDialogProvider } from "@/components/site/app-dialog-provider";
import { CookieNotice } from "@/components/site/cookie-notice";
import { APP_THEME_INIT_SCRIPT } from "@/lib/app-theme-constants";
import { PUBLIC_SITE_DESCRIPTION, PUBLIC_SITE_TITLE, PUBLIC_SITE_URL } from "@/lib/public-positioning";
import "./globals.css";
import "./app-theme.css";
import "./workspace.css";
import "./interior-tokens.css";
import "./web-ui-refresh.css";

// Apply saved Appearance before paint on product routes and public API docs.
// Marketing and authentication routes keep their own presentation.
// AppThemeDocument maintains the same route boundary during client navigation.

const inter = Inter({ subsets: ["latin"], variable: "--font-app-inter", display: "swap" });
const tight = Inter_Tight({ subsets: ["latin"], weight: ["400", "500"], variable: "--font-app-tight", display: "swap" });

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"], weight: ["400", "500", "600"], variable: "--font-jakarta", display: "swap",
});
const mono = Geist_Mono({
  subsets: ["latin"], weight: ["400", "500"], variable: "--font-geist-mono", display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(PUBLIC_SITE_URL),
  title: {
    default: PUBLIC_SITE_TITLE,
    template: "%s | FindEZ",
  },
  description: PUBLIC_SITE_DESCRIPTION,
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
    url: PUBLIC_SITE_URL,
    siteName: "FindEZ",
    type: "website",
    images: [{ url: "/brand/findez-petals-512.png", width: 512, height: 512, alt: "FindEZ" }],
  },
  twitter: {
    card: "summary",
    images: ["/brand/findez-petals-512.png"],
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
  },
  icons: {
    icon: [
      { url: "/brand/findez-tab-20261111-96.png", sizes: "96x96", type: "image/png" },
      { url: "/brand/findez-tab-20261111-16.png", sizes: "16x16", type: "image/png" },
      { url: "/brand/findez-tab-20261111-32.png", sizes: "32x32", type: "image/png" },
      { url: "/brand/findez-tab-20261111.svg", sizes: "any", type: "image/svg+xml" },
    ],
    shortcut: "/brand/findez-tab-20261111-96.png",
    apple: [{ url: "/brand/findez-app-icon-180.png", sizes: "180x180", type: "image/png" }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${jakarta.variable} ${mono.variable} ${inter.variable} ${tight.variable}`} suppressHydrationWarning>
      <head>
        <meta name="theme-color" content="#ffffff" />
        <style>{`html { background: #ffffff; } html.dark { background: #0d0d0f; }`}</style>
        <script dangerouslySetInnerHTML={{ __html: APP_THEME_INIT_SCRIPT }} />
      </head>
      <body className={`${jakarta.className} antialiased`}>
        <Suspense fallback={null}><AppThemeDocument /></Suspense>
        <AppDialogProvider><div style={{ minHeight: '100dvh' }}>{children}</div><CookieNotice /></AppDialogProvider>
      </body>
    </html>
  );
}
