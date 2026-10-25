"use client";
import { useState } from "react";
import Image from "next/image";
import pipStyles from "./chat-pip.module.css";
import { ChevronDown } from "lucide-react";
import { ShinyText } from "./shiny-text";
import styles from "./chat-progress.module.css";

export function ChatProgress({ message }: { message: string }) {
  const text = message || "Understanding your request…";
  const [steps, setSteps] = useState([text]);
  // Record only actual received activity changes; no invented timed milestones.
  if (steps.at(-1) !== text) setSteps(previous => [...previous.slice(-29), text]);
  return <details className={styles.progress}>
    <summary aria-label={`${text} Show progress`}>
      <Image src="/mascot/pip.svg" width={40} height={40} alt="" aria-hidden="true" unoptimized className={pipStyles.pip} style={{ marginBottom: 0, borderRadius: 0 }} />
      <ShinyText text={text} />
      <ChevronDown size={16} aria-hidden="true" />
    </summary>
    <ol aria-label="Activity so far">
      {steps.map((step, index) => <li key={index} aria-current={index === steps.length - 1 ? "step" : undefined}>{step}</li>)}
    </ol>
  </details>;
}
