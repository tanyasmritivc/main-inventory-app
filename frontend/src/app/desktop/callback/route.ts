// Standalone HTML intentionally avoids initializing Supabase in the system browser.
// Only the desktop session has the PKCE verifier and may exchange this code.
export function GET(request: Request) {
  const params = new URL(request.url).searchParams;
  const state = params.get("state") || "";
  const code = params.get("code") || "";
  const duplicate = ["state", "code", "error"].some(key => params.getAll(key).length > 1);
  const valid = !duplicate && /^[A-Za-z0-9_-]{43}$/.test(state) &&
    (/^[A-Za-z0-9._~-]{16,512}$/.test(code) || params.has("error"));
  const target = new URL("findez-desktop://auth/callback");
  if (valid) {
    target.searchParams.set("state", state);
    if (params.has("error")) target.searchParams.set("error", "auth_failed");
    else target.searchParams.set("code", code);
  }
  const action = valid
    ? `<a class="button" href="${target.href.replaceAll("&", "&amp;")}">Return to FindEZ</a>`
    : '<a class="button" href="/desktop">Get FindEZ desktop</a>';
  return new Response(`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer"><meta name="robots" content="noindex,nofollow"><title>Return to FindEZ</title><style>body{margin:0;background:#111112;color:#fafafa;font:17px/1.6 system-ui;display:grid;place-items:center;min-height:100vh}main{max-width:460px;padding:32px}h1{font-size:36px;line-height:1.15}p{color:#aaaab3}.button{display:inline-block;background:white;color:#111;padding:12px 24px;border-radius:12px;text-decoration:none}a:focus-visible{outline:3px solid #77aaff;outline-offset:5px}</style></head><body><main><h1>${valid ? "Continue in FindEZ." : "Start from the desktop app."}</h1><p>${valid ? "Return to the FindEZ app to finish signing in. Your browser may ask permission to open it." : "Open FindEZ and start sign-in again. This link is incomplete or has expired."}</p>${action}</main></body></html>`, {
    status: valid ? 200 : 400,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store", "Referrer-Policy": "no-referrer", "X-Content-Type-Options": "nosniff", "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'" },
  });
}
