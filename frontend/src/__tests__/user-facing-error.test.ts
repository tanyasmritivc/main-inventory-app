import { userFacingError } from "@/lib/user-facing-error";

describe("userFacingError", () => {
  it("never exposes an unknown raw exception", () => {
    expect(userFacingError(new Error("Invalid constraint: deviceId"), "The camera could not start."))
      .toBe("The camera could not start.");
  });

  it("turns known authentication errors into clear guidance", () => {
    expect(userFacingError(new Error("Invalid login credentials"), "Sign in failed."))
      .toBe("The email or password is incorrect.");
  });

  it("turns connectivity errors into clear guidance", () => {
    expect(userFacingError(new TypeError("Failed to fetch"), "Unable to load."))
      .toBe("FindEZ could not connect. Check your connection and try again.");
  });
});
