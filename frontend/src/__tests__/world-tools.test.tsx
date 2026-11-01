/** @jest-environment jsdom */
import {render,screen,fireEvent} from "@testing-library/react";
import {WorldTools} from "@/components/site/world-tools";
jest.mock("@/components/site/inventory-chat-archive",()=>({InventoryChatArchive:({inventoryId}:{inventoryId:string})=><button>Earlier chats {inventoryId}</button>}));
const inventories=[{inventory_id:"hardware",name:"Hardware",workspace_name:"Lab",can_edit:true},{inventory_id:"software",name:"Software",workspace_name:"Lab",can_edit:false}];
test("one compact tool set follows the selected inventory",()=>{
  render(<WorldTools accountId="a" inventories={inventories}/>);
  expect(screen.getAllByRole("link")).toHaveLength(10);
  expect(screen.getByRole("link",{name:/Restock/}).getAttribute("href")).toBe("/restock?inventory=hardware");
  fireEvent.change(screen.getByLabelText("Inventory"),{target:{value:"software"}});
  expect(screen.getByRole("link",{name:/Restock/}).getAttribute("href")).toBe("/restock?inventory=software");
  expect(screen.getByText("View only")).toBeTruthy();
  expect(screen.getByRole("button",{name:"Earlier chats software"})).toBeTruthy();
});
test("removed inventory cannot retain links or archive access",()=>{
  const view=render(<WorldTools accountId="a" inventories={inventories}/>);
  fireEvent.change(screen.getByLabelText("Inventory"),{target:{value:"software"}});
  view.rerender(<WorldTools accountId="a" inventories={[inventories[0]]}/>);
  expect(screen.getAllByRole("link").every(a=>a.getAttribute("href")?.includes("hardware"))).toBe(true);
  view.rerender(<WorldTools accountId="a" inventories={[]}/>);
  expect(screen.queryByRole("link")).toBeNull();
});
