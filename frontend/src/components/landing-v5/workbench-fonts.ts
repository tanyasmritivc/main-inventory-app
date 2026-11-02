import { Inter_Tight, Geist_Mono } from "next/font/google";
const tight = Inter_Tight({ subsets: ["latin"], weight: "400", variable: "--workbench-tight", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: "500", variable: "--workbench-mono", display: "swap" });
export const workbenchFonts = `${tight.variable} ${mono.variable}`;
