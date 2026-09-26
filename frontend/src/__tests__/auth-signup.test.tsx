/** @jest-environment jsdom */

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AuthForm } from "@/components/site/auth-form";

const push = jest.fn();
const refresh = jest.fn();
const signUp = jest.fn();
const signInWithPassword = jest.fn();
const upsert = jest.fn();
const from = jest.fn(() => ({ upsert }));

jest.mock("next/navigation", () => ({
  useRouter: () => ({ push, refresh, replace: jest.fn() }),
  useSearchParams: () => new URLSearchParams("redirect=/inventory"),
}));
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: () => ({ auth: { signUp, signInWithPassword }, from }),
}));
jest.mock("@/components/site/app-dialog-provider", () => ({ useAppDialog: () => ({ showNotice: jest.fn() }) }));

const PENDING_KEY = "findez_pending_signup_profile";

async function submitSignup() {
  render(<AuthForm mode="signup" />);
  await userEvent.type(screen.getByLabelText("First name"), "Ada");
  await userEvent.type(screen.getByLabelText("Last name"), "Lovelace");
  await userEvent.type(screen.getByLabelText("Email"), "  ada@example.com ");
  await userEvent.type(screen.getByLabelText("Password"), "correct horse battery");
  await userEvent.click(screen.getByRole("button", { name: "Create account" }));
}

beforeEach(() => {
  jest.clearAllMocks();
  window.localStorage.clear();
});

test("signup sends a trimmed email and a confirmation link back through /auth/callback", async () => {
  signUp.mockResolvedValue({ data: { user: { id: "u1" }, session: null }, error: null });
  await submitSignup();

  await waitFor(() => expect(signUp).toHaveBeenCalled());
  const args = signUp.mock.calls[0][0];
  expect(args.email).toBe("ada@example.com");
  const redirect = new URL(args.options.emailRedirectTo);
  expect(redirect.origin).toBe(window.location.origin);
  expect(redirect.pathname).toBe("/auth/callback");
  expect(redirect.searchParams.get("next")).toBe("/inventory");
  expect(args.options.data.display_name).toBe("Ada Lovelace");
});

test("when confirmation is required (no session) the user is told to check their email", async () => {
  signUp.mockResolvedValue({ data: { user: { id: "u1" }, session: null }, error: null });
  await submitSignup();

  expect((await screen.findByRole("status")).textContent).toMatch(/check your email/i);
  expect(screen.getByRole("status").textContent).toContain("ada@example.com");
  expect(push).not.toHaveBeenCalled();
  // No session means the browser cannot write the profile; the pending profile is
  // kept so AppShell can complete it after confirmation.
  expect(upsert).not.toHaveBeenCalled();
  expect(JSON.parse(window.localStorage.getItem(PENDING_KEY) ?? "{}")).toMatchObject({ displayName: "Ada Lovelace" });
});

test("when signup returns a session the profile is saved and the user continues", async () => {
  signUp.mockResolvedValue({ data: { user: { id: "u1" }, session: { user: { id: "u1" } } }, error: null });
  upsert.mockResolvedValue({ error: null });
  await submitSignup();

  await waitFor(() => expect(push).toHaveBeenCalledWith("/inventory"));
  expect(from).toHaveBeenCalledWith("profiles");
  expect(upsert).toHaveBeenCalledWith(expect.objectContaining({ id: "u1", first_name: "Ada", last_name: "Lovelace" }));
  expect(screen.queryByRole("alert")).toBeNull();
});

test("a profile save failure is shown instead of being swallowed", async () => {
  signUp.mockResolvedValue({ data: { user: { id: "u1" }, session: { user: { id: "u1" } } }, error: null });
  upsert.mockResolvedValue({ error: { message: "permission denied for table profiles" } });
  await submitSignup();

  expect((await screen.findByRole("alert")).textContent).toMatch(/profile details could not be saved/i);
  expect(screen.getByRole("link", { name: "Continue to FindEZ" }).getAttribute("href")).toBe("/inventory");
  expect(push).not.toHaveBeenCalled();
});

test("a signup error is shown and nothing is saved", async () => {
  signUp.mockResolvedValue({ data: { user: null, session: null }, error: new Error("User already registered") });
  await submitSignup();

  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(upsert).not.toHaveBeenCalled();
  expect(push).not.toHaveBeenCalled();
});

test("sign-in trims the email and keeps the existing redirect", async () => {
  signInWithPassword.mockResolvedValue({ error: null });
  render(<AuthForm mode="signin" />);
  await userEvent.type(screen.getByLabelText("Email"), " ada@example.com ");
  await userEvent.type(screen.getByLabelText("Password"), "secret-password");
  await userEvent.click(screen.getByRole("button", { name: "Sign in" }));

  await waitFor(() => expect(push).toHaveBeenCalledWith("/inventory"));
  expect(signInWithPassword).toHaveBeenCalledWith({ email: "ada@example.com", password: "secret-password" });
});
