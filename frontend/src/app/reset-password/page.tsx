import { Suspense } from "react";
import { ResetPasswordClient } from "@/components/site/reset-password-client";

export default function ResetPasswordPage() {
  return <Suspense fallback={null}><ResetPasswordClient /></Suspense>;
}
