import { organizationNavigation } from "@/lib/context-navigation";

test("organization navigation opens CAD documentation in the same organization", () => {
  const navigation = organizationNavigation("robotics-team", "Robotics", "workspaces");
  expect(navigation.items.find(item => item.label === "CAD Intelligence")?.route).toBe("/docs/cad?world=robotics-team");
  expect(navigation.items.some(item => item.label === "People")).toBe(true);
});


import { worldNavigation } from "@/lib/world-navigation";
test("CAD routes select the hub in the sidebar", () => {
 const nav = worldNavigation("robotics-team", "Robotics", "cad");
 expect(nav.activeRoute).toBe(nav.items.find(item => item.label === "CAD Intelligence")?.route);
});
