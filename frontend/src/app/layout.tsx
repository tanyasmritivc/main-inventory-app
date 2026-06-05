import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
  axes: ["opsz"],
});

export const metadata: Metadata = {
  title: "FindEZ",
  description: "FindEZ",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`dark ${inter.variable}`}>
      <head>
        <meta name="theme-color" content="#000000" />
      </head>
      <body className="antialiased">
        <div className="min-h-dvh">{children}</div>
      </body>
    </html>
  );
}
