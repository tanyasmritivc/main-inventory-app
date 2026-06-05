"use client";

import { Suspense } from "react";
import { AuthForm } from "@/components/site/auth-form";

export default function SignUpPage() {
  return (
    <Suspense fallback={null}>
      <AuthForm mode="signup" />
    </Suspense>
  );
}
