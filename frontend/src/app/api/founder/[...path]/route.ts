import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// The isolated monitoring service enforces founder identity on every data route.
// This gateway adds no credentials and never contacts a user-supplied address.
async function forward(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  const route = path.join("/");
  const allowed = /^(v1\/(snapshot|health|login\/code|issues)|v1\/issues\/[a-zA-Z0-9:-]+)$/.test(route);
  if (!allowed) return NextResponse.json({ detail: "Not found." }, { status: 404 });
  const headers = new Headers({ "Content-Type": "application/json" });
  const authorization = request.headers.get("authorization");
  if (authorization) headers.set("Authorization", authorization);
  const chunks: Uint8Array[] = [];
  let length = 0;
  if (request.body) {
    const reader = request.body.getReader();
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 16_384) {
        await reader.cancel();
        return NextResponse.json({ detail: "Request is too large." }, { status: 413 });
      }
      chunks.push(value);
    }
  }
  const body = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  try {
    const upstream = await fetch(`http://127.0.0.1:8031/dashboard/${route}`, {
      method: request.method,
      headers,
      body: length ? body : undefined,
      cache: "no-store",
      redirect: "error",
      signal: AbortSignal.timeout(45_000),
    });
    return new NextResponse(await upstream.arrayBuffer(), {
      status: upstream.status,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store, private", "X-Content-Type-Options": "nosniff" },
    });
  } catch {
    return NextResponse.json({ detail: "The founder dashboard is temporarily unavailable. Try again shortly." }, { status: 503, headers: { "Cache-Control": "no-store, private" } });
  }
}

export const GET = forward;
export const POST = forward;
export const PATCH = forward;
