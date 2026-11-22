import { cadWorldPath } from "@/lib/cad-links";

import { organizationNavigation } from "@/lib/context-navigation";

test("organization navigation opens CAD in the same organization", () => {
  const navigation = organizationNavigation("robotics-team", "Robotics", "workspaces");
  expect(navigation.items.find(item => item.label === "CAD Intelligence")?.route).toBe("/docs/cad?world=robotics-team");
  expect(navigation.items.some(item => item.label === "People")).toBe(true);
});

test("CAD links preserve the pairing code, organization and section", () => {
  expect(cadWorldPath("/cad/fusion/connect?code=ABCDEFGH23", "test org")).toBe("/cad/fusion/connect?code=ABCDEFGH23&world=test%20org");
  expect(cadWorldPath("/docs/cad#install", "team")).toBe("/docs/cad?world=team#install");
  expect(cadWorldPath("/docs/cad#install", "personal")).toBe("/docs/cad#install");
});
