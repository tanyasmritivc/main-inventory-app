import { organizationNavigation } from "@/lib/context-navigation";

test("organization navigation opens CAD in the same organization", () => {
  const navigation = organizationNavigation("robotics-team", "Robotics", "workspaces");
  expect(navigation.items.find(item => item.label === "CAD Intelligence")?.route).toBe("/cad?world=robotics-team");
  expect(navigation.items.some(item => item.label === "People")).toBe(true);
});
