"use client";
/* eslint-disable @next/next/no-img-element -- Signed private photo URLs must not enter an image proxy. */
import { useState } from "react";

export type MemberIdentity = { user_id: string; display_name?: string; avatar_url?: string; avatar_color?: string };
export function MemberAvatar({ member, size = 30 }: { member?: MemberIdentity; size?: number }) {
  const [failed, setFailed] = useState<string>();
  const name = member?.display_name?.trim() || "Member";
  let url: string | undefined;
  try {
    const parsed = new URL(member?.avatar_url || "");
    if (parsed.protocol === "https:" && !parsed.username && !parsed.password && !parsed.hash) url = parsed.href;
  } catch { /* No saved photo: show initials. */ }
  const color = /^#[a-f\d]{6}$/i.test(member?.avatar_color || "") ? member!.avatar_color : "#636366";
  return <span aria-hidden="true" style={{ display: "inline-flex", position: "relative", alignItems: "center", justifyContent: "center", flexShrink: 0,
    width: size, height: size, borderRadius: "50%", overflow: "hidden", background: color, color: "#fff", fontSize: size * .4 }}>
    {Array.from(name)[0]?.toUpperCase()}
    {url && failed !== url && <img key={url} src={url} alt="" width={size} height={size} referrerPolicy="no-referrer"
      style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }} onError={() => setFailed(url)} />}
  </span>;
}

export function MemberIdentityLabel({ member, prefix }: { member?: MemberIdentity; prefix?: string }) {
  return <span className="member-identity-label"><MemberAvatar member={member} size={24} /><span>{prefix}{member?.display_name || "Member"}</span></span>;
}
