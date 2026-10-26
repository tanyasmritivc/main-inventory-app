import { AuthCallbackClient } from "@/components/site/auth-callback-client";
import { normalizeAuthNext } from "@/lib/auth-callback";

export default async function AuthCallbackPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const code = typeof params.code === "string" ? params.code : null;
  const next = normalizeAuthNext(typeof params.next === "string" ? params.next : null);

  const errorCode = typeof params.error_code === "string" ? params.error_code : typeof params.error === "string" ? params.error : null;
  return <AuthCallbackClient code={code} next={next} errorCode={errorCode} />;
}
