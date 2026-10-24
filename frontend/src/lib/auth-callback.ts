export function normalizeAuthNext(value: string | null | undefined) {
  return value?.startsWith("/") &&
    !value.startsWith("//") &&
    !/[\\\u0000-\u001f]/.test(value)
    ? value
    : "/worlds";
}

type CallbackAuth = {
  exchangeCodeForSession: (
    code: string,
  ) => Promise<{ data: { session: unknown }; error: { code?: string } | null }>;
};
export type CallbackResult =
  | { destination: string; error?: never }
  | { error: string; destination?: never };
export async function resolveAuthCallback(
  auth: CallbackAuth,
  code: string | null,
  next: string,
  errorCode?: string | null,
): Promise<CallbackResult> {
  if (errorCode)
    return {
      error:
        errorCode === "otp_expired"
          ? "This email link has expired or has already been used. Request a new link and use the latest email."
          : "This email link could not be verified. Request a new link and try again.",
    };
  if (!code)
    return {
      error:
        "This email link is incomplete or no longer valid. Request a new link from sign in.",
    };
  try {
    // The callback removes the URL code before client initialization, so this
    // is the only exchange. An existing session cannot validate a new code.
    const { data, error } = await auth.exchangeCodeForSession(code);
    if (error || !data.session)
      return {
        error:
          "This link could not establish a session. Open the latest email in the same browser where you requested it. If your email is already confirmed, sign in with your password.",
      };
    return { destination: normalizeAuthNext(next) };
  } catch {
    return {
      error:
        "FindEZ could not finish verifying this link. Check your connection and request a new link if needed.",
    };
  }
}
