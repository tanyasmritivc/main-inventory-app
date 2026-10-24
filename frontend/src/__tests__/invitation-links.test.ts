import { redirect } from "next/navigation";
import LegacySpaceInvitationPage from "@/app/join/page";
import { generateMetadata as spaceMetadata } from "@/app/join/[code]/page";
import { generateMetadata as teamMetadata } from "@/app/join/team/[code]/page";
import { APP_STORE_URL, invitationAppSchemeLink, invitationUniversalLink, isIosDevice } from "@/lib/app-store";
import { invitationHandoff, normalizeInvitationCode } from "@/lib/invitation";

jest.mock("next/navigation", () => ({ redirect: jest.fn(), useRouter: () => ({ replace: jest.fn() }) }));

test("invitation link helpers use the official listing and associated domain", () => {
  expect(APP_STORE_URL).toBe("https://apps.apple.com/us/app/findez-ai/id6760401697");
  expect(invitationUniversalLink("space", "ABC123")).toBe("https://www.findez.ai/join/ABC123");
  expect(invitationUniversalLink("team", "TEAM12")).toBe("https://www.findez.ai/join/team/TEAM12");
  expect(invitationAppSchemeLink("space", "ABC123")).toBe("findez://space-invite?code=ABC123");
  expect(isIosDevice("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)")).toBe(true);
  expect(isIosDevice("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", 5)).toBe(true);
  expect(isIosDevice("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", 0)).toBe(false);
  expect(isIosDevice("Mozilla/5.0 (Linux; Android 16)")).toBe(false);
});

test("legacy /join?code= links from earlier emails redirect to the Universal Link path", async () => {
  await LegacySpaceInvitationPage({ searchParams: Promise.resolve({ code: "abc123" }) });
  expect(redirect).toHaveBeenCalledWith("/join/ABC123");
  jest.mocked(redirect).mockClear();
  await LegacySpaceInvitationPage({ searchParams: Promise.resolve({ code: "bad" }) });
  expect(redirect).not.toHaveBeenCalled();
});

test("invitation pages advertise the app with the invitation as the Smart App Banner argument", async () => {
  const space = await spaceMetadata({ params: Promise.resolve({ code: "abc123" }) });
  expect(space.itunes).toEqual({ appId: "6760401697", appArgument: "https://www.findez.ai/join/ABC123" });
  const team = await teamMetadata({ params: Promise.resolve({ code: "team12" }) });
  expect(team.itunes).toEqual({ appId: "6760401697", appArgument: "https://www.findez.ai/join/team/TEAM12" });
  const invalid = await spaceMetadata({ params: Promise.resolve({ code: "x" }) });
  expect(invalid.itunes).toEqual({ appId: "6760401697" });
});

test("malformed or overlong codes cannot be normalized into another invitation", () => {
  for (const code of ["ABC123extra", "ABC!23", "ABC123/", "ABC%23"]) expect(normalizeInvitationCode(code)).toBe("");
  expect(normalizeInvitationCode("abc123")).toBe("ABC123");
  expect(invitationHandoff("/join/ABC123?download=1", 100)).toEqual({ v: 1, kind: "space", code: "ABC123", created_at: 100 });
  for (const path of ["//evil.test/join/ABC123", "/join/ABC123extra", "/join/ABC123?role=owner", "/join/team/ABC123/extra"]) expect(invitationHandoff(path)).toBeNull();
});
