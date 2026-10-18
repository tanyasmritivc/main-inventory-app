import type { Metadata } from "next";
import { DM_Sans, Inter, Syne } from "next/font/google";
import { AppDialogProvider } from "@/components/site/app-dialog-provider";
import { CookieNotice } from "@/components/site/cookie-notice";
import { APP_THEME_STORAGE_KEY, INTERIOR_PATH_PREFIXES } from "@/lib/app-theme-constants";
import { PUBLIC_SITE_DESCRIPTION, PUBLIC_SITE_TITLE, PUBLIC_SITE_URL } from "@/lib/public-positioning";
import "./globals.css";
import "./app-theme.css";
import "./workspace.css";
import "@fontsource-variable/source-sans-3/wght.css";
import "@fontsource-variable/source-sans-3/wght-italic.css";

// Runs before first paint, on every route, because layout.tsx wraps the
// whole app. It must stay a no-op outside the interior: it checks the
// path against INTERIOR_PATH_PREFIXES first and returns immediately for
// marketing, pricing, robotics, auth and every other non-interior route,
// so the landing page never sees a dark class regardless of the visitor's
// system preference or a stored choice from a previous interior visit.
// Without this, AppThemeProvider's useEffect would apply the theme after
// hydration, and a dark-mode visitor would see a white flash on every
// interior page load.
const THEME_INIT_SCRIPT = `(function(){try{var p=["${INTERIOR_PATH_PREFIXES.join('","')}"];var path=window.location.pathname;var isInterior=false;for(var i=0;i<p.length;i++){if(path===p[i]||path.indexOf(p[i]+"/")===0){isInterior=true;break;}}if(!isInterior)return;var stored=window.localStorage.getItem(${JSON.stringify(APP_THEME_STORAGE_KEY)});var dark=stored==="dark"||(stored!=="light"&&window.matchMedia("(prefers-color-scheme: dark)").matches);if(dark)document.documentElement.classList.add("dark");}catch(e){}})();`;

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
  metadataBase: new URL(PUBLIC_SITE_URL),
  title: {
    default: PUBLIC_SITE_TITLE,
    template: "%s | FindEZ AI",
  },
  description: PUBLIC_SITE_DESCRIPTION,
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
    url: PUBLIC_SITE_URL,
    siteName: "FindEZ AI",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
  },
  icons: {
    icon: "/images/findez-favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${syne.variable} ${dmSans.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <meta name="theme-color" content="#ffffff" />
      </head>
      <body className={`${inter.className} antialiased`}>
        <AppDialogProvider><div style={{ minHeight: '100dvh' }}>{children}</div><CookieNotice /></AppDialogProvider>
      </body>
    </html>
  );
}
