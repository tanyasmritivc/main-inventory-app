"use client";
import { useEffect, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { PlanComparison } from "./plan-comparison";
import { dismissLocally, persistPlanIntroduction, shouldIntroducePlans } from "@/lib/plan-introduction";
import { isPilotPublic } from "@/lib/pilot";
import styles from "./plans-usage.module.css";

export function PlanIntroduction({ accountId }: { accountId: string }) {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    // Preserve direct conversation, invitation and prompt handoffs.
    if (window.location.search || window.location.hash) return;
    let active = true;
    const controller = new AbortController();
    void shouldIntroducePlans(accountId, controller.signal).then(show => {
      if (active && !controller.signal.aborted) setOpen(show);
    }).catch(() => {}); // Optional introduction must never block chat on an auth read failure.
    return () => { active = false; controller.abort(); };
  }, [accountId]);
  function close() {
    setOpen(false);
    dismissLocally(accountId);
    void persistPlanIntroduction(accountId, AbortSignal.timeout(10000)).catch(() => {});
  }
  return <PlanWelcomeDialog open={open} onClose={close}/>;
}

export function PlanWelcomeDialog({open, onClose: close}: {open: boolean; onClose: () => void}) {
  return <Dialog open={open} onOpenChange={value => { if (!value) close(); }}>
    <DialogContent className={styles.dialog}>
      <DialogTitle className={styles.dialogTitle}>A plan for your world.</DialogTitle>
      <DialogDescription className={styles.dialogDescription}>
        {isPilotPublic() ? "Free during early access. No plan limits or automatic charges." : "Start with Free. Paid plans are coming soon."}
      </DialogDescription>
      <PlanComparison onContinue={close} signedIn />
      <p className={styles.footnote}>These allowances start when subscriptions launch. You can compare plans anytime in the sidebar.</p>
      <div className={styles.dialogFooter}><button className={styles.skip} onClick={close}>Skip for now</button></div>
    </DialogContent>
  </Dialog>;
}
