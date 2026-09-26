import { ApiError, SESSION_EXPIRED_MESSAGE, apiRequest, getSpaces } from "@/lib/api";
import { getAccessToken } from "@/lib/session";

jest.mock("@/lib/session", () => ({ getAccessToken: jest.fn() }));

const fetchMock = jest.fn();

function jsonResponse(status: number, body: unknown) {
  const text = body === undefined ? "" : JSON.stringify(body);
  return { ok: status >= 200 && status < 300, status, text: async () => text } as Response;
}

beforeEach(() => {
  fetchMock.mockReset();
  jest.mocked(getAccessToken).mockReset();
  global.fetch = fetchMock as unknown as typeof fetch;
});

test("authenticates with the live session token, not a stale component token", async () => {
  jest.mocked(getAccessToken).mockResolvedValue("live-token");
  fetchMock.mockResolvedValue(jsonResponse(200, [{ id: "s1", name: "Garage", created_at: null }]));

  await expect(getSpaces({ token: "stale-token" })).resolves.toEqual([{ id: "s1", name: "Garage", created_at: null }]);
  expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe("Bearer live-token");
});

test("falls back to an explicit token when no session is readable", async () => {
  jest.mocked(getAccessToken).mockResolvedValue(null);
  fetchMock.mockResolvedValue(jsonResponse(200, { ok: true }));

  await apiRequest("/profile/me", { token: "explicit-token" });
  expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe("Bearer explicit-token");
});

test("an unauthenticated request fails consistently without calling the API", async () => {
  jest.mocked(getAccessToken).mockResolvedValue(null);

  const error = await apiRequest("/spaces").catch((reason: unknown) => reason);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(401);
  expect((error as ApiError).message).toBe(SESSION_EXPIRED_MESSAGE);
  expect(fetchMock).not.toHaveBeenCalled();
});

test("API errors keep mapping through ApiError with user-facing messages", async () => {
  jest.mocked(getAccessToken).mockResolvedValue("token");
  fetchMock.mockResolvedValueOnce(jsonResponse(403, { detail: "internal policy trace" }));

  const forbidden = await apiRequest("/spaces").catch((reason: unknown) => reason);
  expect(forbidden).toBeInstanceOf(ApiError);
  expect((forbidden as ApiError).status).toBe(403);
  expect((forbidden as ApiError).message).toBe("You don't have permission to do that.");

  fetchMock.mockResolvedValueOnce(jsonResponse(429, { detail: { upgrade_required: true } }));
  const limited = await apiRequest("/usage/check", { method: "POST", body: { feature: "x" } }).catch((reason: unknown) => reason);
  expect((limited as ApiError).limitExceeded).toBe(true);
  expect((limited as ApiError).upgrade_required).toBe(true);
});

test("JSON bodies are serialized and FormData is passed through", async () => {
  jest.mocked(getAccessToken).mockResolvedValue("token");
  fetchMock.mockResolvedValue(jsonResponse(200, {}));

  await apiRequest("/spaces", { method: "POST", body: { name: "Shed" } });
  expect(fetchMock.mock.calls[0][1].body).toBe(JSON.stringify({ name: "Shed" }));
  expect(fetchMock.mock.calls[0][1].headers["Content-Type"]).toBe("application/json");

  const form = new FormData();
  await apiRequest("/import/spreadsheet", { method: "POST", body: form });
  expect(fetchMock.mock.calls[1][1].body).toBe(form);
  expect(fetchMock.mock.calls[1][1].headers["Content-Type"]).toBeUndefined();
});

test("an aborted request rejects with the AbortError instead of a network error", async () => {
  jest.mocked(getAccessToken).mockResolvedValue("token");
  const controller = new AbortController();
  fetchMock.mockImplementation((_url: string, init: RequestInit) => {
    expect(init.signal).toBe(controller.signal);
    return Promise.reject(Object.assign(new Error("aborted"), { name: "AbortError" }));
  });
  controller.abort();

  await expect(apiRequest("/spaces", { signal: controller.signal })).rejects.toMatchObject({ name: "AbortError" });
});

test("a network failure maps to a connection ApiError", async () => {
  jest.mocked(getAccessToken).mockResolvedValue("token");
  fetchMock.mockRejectedValue(new TypeError("Failed to fetch"));

  const error = await apiRequest("/spaces").catch((reason: unknown) => reason);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(0);
});
