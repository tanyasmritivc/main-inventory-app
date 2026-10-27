"use client";
import Link from "next/link";
import { useRef, useState } from "react";
import { ArrowUpRight, Sparkles } from "lucide-react";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { PlanComparison } from "./plan-comparison";
import { isPilotPublic } from "@/lib/pilot";
import styles from "./plans-usage.module.css";

export function SidebarUpgrade({onOpen}: {onOpen?: () => void}) {
  const [open, setOpen] = useState(false);
  const trigger = useRef<HTMLButtonElement>(null);
  return <Dialog open={open} onOpenChange={value => {setOpen(value); if (value) onOpen?.();}}>
    <DialogTrigger asChild><button ref={trigger} type="button" className="app-upgrade-link" aria-label="Upgrade - compare plans" title="Compare plans">
      <Sparkles size={18} aria-hidden="true"/><span>Upgrade</span><ArrowUpRight size={16} className="app-upgrade-arrow" aria-hidden="true"/>
    </button></DialogTrigger>
    <DialogContent className={`${styles.dialog} ${styles.upgradeDialog}`} onCloseAutoFocus={event => {
      if (!trigger.current?.getClientRects().length) {event.preventDefault(); document.querySelector<HTMLButtonElement>('button[aria-label="Open navigation"]')?.focus();}
    }}>
      <DialogTitle className={styles.dialogTitle}>Find your plan</DialogTitle>
      <DialogDescription className={styles.dialogDescription}>{isPilotPublic() ? "Free during early access. No plan limits or automatic charges." : "Start with Free. Paid plans are coming soon."}</DialogDescription>
      <PlanComparison signedIn onContinue={() => setOpen(false)}/>
      <div className={styles.upgradeFooter}><button type="button" className={styles.skip} onClick={() => setOpen(false)}>Not now</button><Link href="/settings/plans" className={styles.fullPlans} onClick={() => setOpen(false)}>View plans and usage <ArrowUpRight size={15}/></Link></div>
    </DialogContent>
  </Dialog>;
}
