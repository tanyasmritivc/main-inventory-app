import Link from "next/link";

// Keep legacy entry points informational until verified subscriptions launch.
export function UpgradeCheckoutLink(props: { className?: string }) {
  return <Link href="/pricing" className={props.className}>Compare plans</Link>;
}
