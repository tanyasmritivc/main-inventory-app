import CadPage from "@/app/cad/page";
import { requireUser } from "@/lib/auth-guard";

jest.mock("@/lib/auth-guard", () => ({ requireUser: jest.fn() }));
jest.mock("@/components/site/inventory-boundary", () => ({ InventoryBoundary: () => null }));
jest.mock("@/components/cad/cad-client", () => ({ CadClient: () => null }));

test("CAD verifies sign-in before returning the client inventory gate", async () => {
  jest.mocked(requireUser).mockRejectedValue(new Error("redirect-to-signin"));
  await expect(CadPage({ searchParams: Promise.resolve({ inventory: "selected-inventory" }) })).rejects.toThrow("redirect-to-signin");
  expect(requireUser).toHaveBeenCalledWith("/cad?inventory=selected-inventory");
});
