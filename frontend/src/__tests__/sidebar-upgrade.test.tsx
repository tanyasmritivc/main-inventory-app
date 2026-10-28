/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import { SidebarUpgrade } from "@/components/site/sidebar-upgrade";

test('Upgrade opens existing prices in a modal, with a full-page link and no purchase', async () => {
  const onOpen=jest.fn();
  render(<SidebarUpgrade onOpen={onOpen}/>);
  const trigger=screen.getByRole('button',{name:'Upgrade - compare plans'});
  fireEvent.click(trigger);
  expect(await screen.findByRole('dialog')).toBeTruthy();
  expect(onOpen).toHaveBeenCalledTimes(1);
  expect(screen.getByText('$29')).toBeTruthy();
  expect(screen.getByText('10 people included')).toBeTruthy();
  fireEvent.click(screen.getByRole('button',{name:'Yearly'}));
  expect(screen.getByText('$299')).toBeTruthy();
  expect(screen.getByRole('button',{name:'Team subscriptions coming soon'}).hasAttribute('disabled')).toBe(true);
  expect(screen.getByRole('link',{name:'View plans and usage'}).getAttribute('href')).toBe('/settings/plans');
  fireEvent.click(screen.getByRole('button',{name:'Not now'}));
  await waitFor(()=>expect(screen.queryByRole('dialog')).toBeNull());
});
