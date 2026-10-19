import { redirect } from "next/navigation";

// Retain the preview URL without exposing obsolete waitlist or feature demos.
export default function LabPage() {
  redirect("/");
}
