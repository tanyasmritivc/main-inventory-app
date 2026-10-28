import { Inter, Plus_Jakarta_Sans, Geist_Mono } from "next/font/google";
const inter = Inter({subsets:["latin"],weight:["400","500","600"],variable:"--landing-inter",display:"swap"});
const jakarta = Plus_Jakarta_Sans({ subsets: ["latin"], weight: ["500", "600"], variable: "--landing-jakarta", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: ["400"], variable: "--landing-mono", display: "swap" });
export const publicFonts = `${inter.variable} ${jakarta.variable} ${mono.variable}`;
