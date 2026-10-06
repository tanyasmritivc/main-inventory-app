"use client";
import { InteriorError } from "@/components/site/interior-state";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return <InteriorError reset={reset} />;
}
