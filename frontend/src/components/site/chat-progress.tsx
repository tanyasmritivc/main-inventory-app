"use client";
import { useEffect, useState } from "react";
import Image from "next/image";
import pipStyles from "./chat-pip.module.css";
import { ChevronDown } from "lucide-react";
import { ShinyText } from "./shiny-text";
import styles from "./chat-progress.module.css";

export function ChatProgress({ message, startedAt, lastActivityAt = null }: {
  message: string;
  startedAt?: number;
  lastActivityAt?: number | null;
}) {
  const [mountedAt] = useState(() => Date.now());
  const [now, setNow] = useState(mountedAt);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);
  const elapsed = Math.max(0, Math.floor((now - (startedAt ?? mountedAt)) / 1000));
  const age = lastActivityAt === null ? null : Math.max(0, Math.floor((now - lastActivityAt) / 1000));
  const duration = (seconds: number) => seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  const text = message || "Understanding your request…";
  const [steps, setSteps] = useState([text]);
  // Record only actual received activity changes; no invented timed milestones.
  if (steps.at(-1) !== text) setSteps(previous => [...previous.slice(-29), text]);
  const retrying = steps.some(step => step.startsWith("Retrying the interrupted response"));
  return <div className={styles.progress}><details>
    <summary aria-label={`${text} Show progress`}>
      <Image src="/mascot/pip.svg" width={40} height={40} alt="" aria-hidden="true" unoptimized className={pipStyles.pip} style={{ marginBottom: 0, borderRadius: 0 }} />
      <ShinyText text={text} />
      <ChevronDown size={16} aria-hidden="true" />
    </summary>
    <ol aria-label="Activity so far">
      {steps.map((step, index) => <li key={index} aria-current={index === steps.length - 1 ? "step" : undefined}>{step}</li>)}
    </ol>
  </details>
    <p className={styles.timing} role="timer" aria-live="off">
      {retrying ? "Second attempt · " : ""}{duration(elapsed)} elapsed · {age === null ? "Waiting for server updates" : age < 6 ? "Receiving updates" : `Last update ${duration(age)} ago`}
    </p>
  </div>;
}
