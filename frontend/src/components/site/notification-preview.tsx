"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import * as Menu from "@radix-ui/react-dropdown-menu";
import { Bell, ArrowRight } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import type { ActivityEntry } from "@/lib/api";
import { publishNotificationSnapshot } from "@/lib/notification-state";
import styles from "./notification-preview.module.css";

type Props = { accountId: string | null; unread: number | null };
export function NotificationPreview(props: Props) {
  return <AccountPreview key={props.accountId || "signed-out"} {...props} />;
}
function AccountPreview({accountId, unread}: Props) {
  const [open, setOpen] = useState(false);
  const [entries, setEntries] = useState<ActivityEntry[]>();
  const [error, setError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    if (!open || !accountId) return;
    const control = new AbortController();
    accountRequest<{notifications: ActivityEntry[]; unread_count: number}>(accountId, "/notifications", {signal: control.signal})
      .then(result => {
        if (control.signal.aborted) return;
        if (!Array.isArray(result.notifications) || !Number.isSafeInteger(result.unread_count) || result.unread_count < 0)
          throw new Error("Invalid notification result");
        setEntries(result.notifications.slice(0, 5));
        publishNotificationSnapshot(accountId, result.unread_count);
      }).catch(() => { if (!control.signal.aborted) setError(true); });
    return () => control.abort();
  }, [accountId, open, attempt]);
  return <Menu.Root open={open} onOpenChange={value => {setOpen(value); if (value) {setError(false); setEntries(undefined);}}} modal={false}>
    <Menu.Trigger asChild><button type="button" className="app-icon-button app-notification-button"
      aria-label={unread === null ? "Notifications" : `${unread} unread notifications`} disabled={!accountId}>
      <Bell size={18} />{unread !== null && unread > 0 && <span>{unread > 99 ? "99+" : unread}</span>}
    </button></Menu.Trigger>
    <Menu.Portal><Menu.Content className={styles.panel} align="end" sideOffset={10} collisionPadding={12} aria-label="Recent notifications">
      <Menu.Label className={styles.heading}>Notifications</Menu.Label>
      {!entries && !error && <p className={styles.message} role="status">Loading notifications...</p>}
      {error && <><p className={styles.message} role="alert">Notifications could not load.</p><Menu.Item className={styles.footer} onSelect={e => {e.preventDefault(); setError(false); setEntries(undefined); setAttempt(v => v + 1);}}>Try again</Menu.Item></>}
      {entries?.length === 0 && <p className={styles.message}>You&apos;re all caught up.</p>}
      {entries?.map((entry, index) => <Menu.Item asChild key={entry.activity_id || entry.id || index}>
        <Link className={styles.entry} href={entry.invitation?.invitation_id
          ? `/join/access?invitation=${encodeURIComponent(entry.invitation.invitation_id)}`
          : `/notifications#notification-${encodeURIComponent(entry.activity_id || entry.id || String(index))}`}>
          <Bell size={15} className={styles.icon} aria-hidden="true" />
          <span><span className={styles.copy}>{entry.display_text || entry.summary}</span><small>{entry.team_name || entry.activity_type || "FindEZ"}</small></span>
          {entry.is_read === false && <span className={styles.dot} aria-label="Unread" />}
        </Link>
      </Menu.Item>)}
      <Menu.Separator className={styles.separator}/>
      <Menu.Item asChild><Link className={styles.footer} href="/notifications">View all notifications <ArrowRight size={15}/></Link></Menu.Item>
    </Menu.Content></Menu.Portal>
  </Menu.Root>;
}
