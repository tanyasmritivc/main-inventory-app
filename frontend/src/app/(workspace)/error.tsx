"use client";
import { InteriorError } from "@/components/site/interior-state";

export default function Error({ reset }: { reset: () => void }) {
  return <InteriorError reset={reset} />;
}
