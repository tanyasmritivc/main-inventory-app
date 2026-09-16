"use client";

import type { LucideIcon } from "lucide-react";
import {
  Barcode,
  BookOpen,
  Boxes,
  Camera,
  ChevronDown,
  Code2,
  KeyRound,
  MapPin,
  PackageCheck,
  Search,
  Sparkles,
  Users,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import styles from "./nav.module.css";

type MenuItem = {
  label: string;
  description: string;
  href: string;
  icon: LucideIcon;
};

type MenuGroup = {
  label: string;
  href: string;
  match: string;
  items: MenuItem[];
};

const NAV_GROUPS: MenuGroup[] = [
  {
    label: "Product",
    href: "/product",
    match: "/product",
    items: [
      { label: "Product overview", description: "See the complete inventory system", href: "/product", icon: Boxes },
      { label: "Capture inventory", description: "Photos, barcodes, and spreadsheets", href: "/product/capture", icon: Camera },
      { label: "Ask FindEZ", description: "Search and update in plain language", href: "/product/ask", icon: Sparkles },
      { label: "Spaces & sharing", description: "Organize by place and work together", href: "/product/spaces-and-sharing", icon: MapPin },
    ],
  },
  {
    label: "How it works",
    href: "/product#capture",
    match: "/how-it-works",
    items: [
      { label: "Bring items in", description: "Turn real-world inputs into records", href: "/product#capture", icon: Barcode },
      { label: "Give everything a place", description: "Mirror shelves, bins, and rooms", href: "/product#organize", icon: MapPin },
      { label: "Find what you need", description: "Search by item, detail, or location", href: "/product#find", icon: Search },
    ],
  },
  {
    label: "For robotics",
    href: "/robotics",
    match: "/robotics",
    items: [
      { label: "Robotics teams", description: "Inventory for FTC, FRC, VEX, and FLL", href: "/robotics", icon: Users },
      { label: "Project kits", description: "Check parts before the build starts", href: "/project-kits", icon: PackageCheck },
      { label: "Shared team inventory", description: "Keep the shop and pit in sync", href: "/teams", icon: Boxes },
    ],
  },
  {
    label: "Developers",
    href: "/docs/api",
    match: "/docs/api",
    items: [
      { label: "API documentation", description: "Endpoints, schemas, and examples", href: "/docs/api", icon: BookOpen },
      { label: "Quickstart", description: "Make your first inventory request", href: "/docs/api#quickstart", icon: Code2 },
      { label: "AI assistants", description: "Connect ChatGPT or Claude", href: "/docs/api#ai-assistants", icon: Sparkles },
      { label: "API keys", description: "Create and manage credentials", href: "/settings/api-keys", icon: KeyRound },
    ],
  },
];

export function SiteNav(props: { variant: "marketing" | "app"; theme?: "light" | "dark" }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  if (props.variant === "app") return null;
  const closeMenu = () => setMobileOpen(false);

  return (
    <header className={`${styles.header} ${props.theme === "light" ? styles.light : styles.dark}`}>
      <div className={styles.inner}>
        <Link href="/" className={styles.brand} aria-label="FindEZ home" onClick={closeMenu}>
          <span className={styles.brandMark} aria-hidden="true"><i /></span>
          FindEZ
        </Link>

        <nav className={styles.desktopNav} aria-label="Marketing navigation">
          {NAV_GROUPS.map((group) => {
            const active = pathname === group.match || pathname.startsWith(`${group.match}/`);
            return (
              <div className={styles.menuGroup} key={group.label}>
                <Link href={group.href} className={`${styles.menuTrigger} ${active ? styles.active : ""}`}>
                  {group.label}
                  <ChevronDown size={13} strokeWidth={1.8} aria-hidden="true" />
                </Link>
                <div className={styles.menuPanel}>
                  <div className={styles.menuGrid}>
                    {group.items.map((item) => {
                      const Icon = item.icon;
                      return (
                        <Link href={item.href} className={styles.menuItem} key={`${group.label}-${item.label}`}>
                          <span className={styles.menuIcon}><Icon size={17} strokeWidth={1.7} /></span>
                          <span>
                            <strong>{item.label}</strong>
                            <small>{item.description}</small>
                          </span>
                        </Link>
                      );
                    })}
                  </div>
                </div>
              </div>
            );
          })}
        </nav>

        <div className={styles.actions}>
          <Link href="/signin" className={styles.signin} onClick={closeMenu}>Sign in</Link>
          <Link href="/signup" className={styles.cta} onClick={closeMenu}>Start free</Link>
          <button
            type="button"
            className={`${styles.mobileToggle} ${mobileOpen ? styles.mobileToggleOpen : ""}`}
            aria-label="Toggle navigation"
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen((open) => !open)}
          >
            <span /><span />
          </button>
        </div>
      </div>

      {mobileOpen ? (
        <nav className={styles.mobileNav} aria-label="Mobile marketing navigation">
          {NAV_GROUPS.map((group) => (
            <details className={styles.mobileGroup} key={group.label}>
              <summary>{group.label}<ChevronDown size={15} /></summary>
              <div>
                {group.items.map((item) => (
                  <Link key={`${group.label}-${item.label}`} href={item.href} onClick={closeMenu}>
                    <strong>{item.label}</strong>
                    <span>{item.description}</span>
                  </Link>
                ))}
              </div>
            </details>
          ))}
          <div className={styles.mobileActions}>
            <Link href="/signin" onClick={closeMenu}>Sign in</Link>
            <Link href="/signup" onClick={closeMenu}>Start free</Link>
          </div>
        </nav>
      ) : null}
    </header>
  );
}
