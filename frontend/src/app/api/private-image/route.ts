import { createSupabaseServerClient } from "@/lib/supabase/server";
export const dynamic = "force-dynamic";
const headers = {"Cache-Control":"private, no-store, max-age=0", "Pragma":"no-cache", "X-Content-Type-Options":"nosniff", "Vary":"Cookie"};
export async function GET(request: Request) {
  const path = new URL(request.url).searchParams.get("path") || "";
  if (path.length>1024 || !/^[0-9a-f-]{36}\//i.test(path) || path.includes("\\") || /%[0-9a-f]{2}/i.test(path) || path.split("/").some(p=>!p || p==="." || p==="..")) return new Response(null,{status:400,headers});
  try {
    const supabase=await createSupabaseServerClient();
    const {data,error}=await supabase.auth.getSession();
    if(error || !data.session) return new Response(null,{status:401,headers});
    const base=process.env.NEXT_PUBLIC_API_BASE_URL;
    if(!base) return new Response(null,{status:503,headers});
    const response=await fetch(`${base.replace(/\/$/,"")}/media/item-image?path=${encodeURIComponent(path)}`,{
      headers:{Authorization:`Bearer ${data.session.access_token}`},cache:"no-store",redirect:"error",signal:AbortSignal.timeout(20_000),
    });
    if(!response.ok) return new Response(null,{status:[401,403,404].includes(response.status)?response.status:503,headers});
    const mime=response.headers.get("content-type") || "application/octet-stream";
    if(!/^image\/(jpeg|png|webp|gif|heic|avif)(;|$)/.test(mime)) return new Response(null,{status:415,headers});
    return new Response(response.body,{headers:{...headers,"Content-Type":mime,"Content-Security-Policy":"default-src 'none'; sandbox"}});
  } catch { return new Response(null,{status:503,headers}); }
}
