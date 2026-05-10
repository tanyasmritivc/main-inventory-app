import { Suspense } from "react";
import Link from "next/link";

import { AuthForm } from "@/components/site/auth-form";

export default function SignUpPage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4">
      <div className="w-full max-w-[400px]">
        <div className="mb-8 text-center">
          <div className="text-[22px] font-bold text-white tracking-tight">FindEZ</div>
        </div>
        <Suspense fallback={null}>
          <AuthForm mode="signup" />
        </Suspense>
        <div className="mt-5 text-center text-sm text-white/45">
          Already have an account?{" "}
          <Link href="/signin" className="text-white/70 hover:text-white underline-offset-4 hover:underline transition-colors">Sign in</Link>
        </div>
      </div>
    </div>
  );
}
