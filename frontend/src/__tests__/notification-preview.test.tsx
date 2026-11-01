/** @jest-environment jsdom */
import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import {NotificationPreview} from "@/components/site/notification-preview";
import {accountRequest} from "@/lib/account-request";
jest.mock("@/lib/account-request", () => ({accountRequest:jest.fn()}));
const row = {id:"one", summary:"Alex added bolts", created_at:"2026-10-26T00:00:00Z", is_read:false};
beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(accountRequest).mockReset();
  global.ResizeObserver = class {observe(){} unobserve(){} disconnect(){}};
  window.HTMLElement.prototype.scrollIntoView = jest.fn();
  jest.mocked(accountRequest).mockResolvedValue({notifications:[row],unread_count:1});
});
async function open() {await act(async () => {fireEvent.keyDown(screen.getByRole("button", {name:/notifications/i}), {key:"Enter"});});}
test("bell previews five entries without marking them read and links to full inbox", async () => {
  jest.mocked(accountRequest).mockResolvedValue({notifications:Array.from({length:7},(_,i)=>({...row,id:String(i),summary:`Update ${i}`})),unread_count:7});
  render(<NotificationPreview accountId="a" unread={7}/>);
  expect(accountRequest).not.toHaveBeenCalled();
  await open();
  await screen.findByText("Update 0");
  expect(screen.queryByText("Update 5")).toBeNull();
  expect(screen.getByRole("menuitem", {name:/View all notifications/}).getAttribute("href")).toBe("/notifications");
  expect(jest.mocked(accountRequest).mock.calls.every(([,path])=>path==="/notifications")).toBe(true);
  fireEvent.keyDown(screen.getByRole("menu"), {key:"Escape"});
  await waitFor(()=>expect(screen.queryByRole("menu")).toBeNull());
});
test("failed load can retry without reporting an empty inbox", async () => {
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("private database detail"));
  render(<NotificationPreview accountId="a" unread={null}/>);
  await open(); await screen.findByRole("alert");
  expect(screen.queryByText(/private database/)).toBeNull();
  fireEvent.click(screen.getByRole("menuitem", {name:"Try again"}));
  await screen.findByText(row.summary);
});
test("account change closes preview and discards a late old response", async () => {
  let resolve!: (v: unknown)=>void;
  jest.mocked(accountRequest).mockImplementation(()=>new Promise(r=>{resolve=r;}));
  const view=render(<NotificationPreview accountId="a" unread={1}/>);
  await open(); await screen.findByRole("menu");
  view.rerender(<NotificationPreview accountId="b" unread={null}/>);
  await act(async()=>resolve({notifications:[row],unread_count:1}));
  expect(screen.queryByText(row.summary)).toBeNull();
  expect(screen.queryByRole("menu")).toBeNull();
});
