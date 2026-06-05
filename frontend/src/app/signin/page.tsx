"use client";

import { Suspense } from "react";
import { AuthForm } from "@/components/site/auth-form";

export default function SignInPage() {
  return (
    <Suspense fallback={null}>
      <AuthForm mode="signin" />
    </Suspense>
  );
}
