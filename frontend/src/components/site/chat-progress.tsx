"use client";
import { useEffect, useState } from "react";
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
  const text = (message || "Understanding your request...").replace(/…/g, "...");
  const [activity, setActivity] = useState({last: text, steps: [{text, count: 1}], retrying: text.startsWith("Retrying the interrupted response")});
  // Only received phase changes add an update. Elapsed time never invents work.
  if (activity.last !== text) {
    const previous = activity.steps.find(step => step.text === text);
    setActivity({last: text,
      steps: [...activity.steps.filter(step => step.text !== text).slice(-5), {text, count: (previous?.count ?? 0) + 1}],
      retrying: activity.retrying || text.startsWith("Retrying the interrupted response")});
  }
  const {steps, retrying} = activity;
  return <div className={styles.progress}><details>
    <summary aria-label={`${text} Show progress`}>
      <ShinyText text={text} />
      <ChevronDown size={16} aria-hidden="true" />
    </summary>
    <ol aria-label="Activity so far">
      {steps.map((step, index) => <li key={step.text} aria-current={index === steps.length - 1 ? "step" : undefined}><span>{step.text}</span>{step.count > 1 && <small aria-label={`${step.count} received updates`}>{step.count} updates</small>}</li>)}
    </ol>
  </details>
    <p className={styles.timing} role="timer" aria-live="off">
      {retrying ? "Second attempt · " : ""}{duration(elapsed)} elapsed · {age === null ? "Waiting for server updates" : age < 6 ? "Receiving updates" : `Last update ${duration(age)} ago`}
    </p>
  </div>;
}
