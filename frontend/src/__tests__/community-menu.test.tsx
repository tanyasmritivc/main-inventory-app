/** @jest-environment jsdom */
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CommunityMenu } from '@/components/marketing-dark/community-menu';
afterEach(cleanup);

test('keyboard navigation opens both destinations and Escape returns focus', async () => {
  const user = userEvent.setup();
  render(<CommunityMenu />);
  const trigger = screen.getByRole('button', { name: 'Community' });
  expect(screen.queryByRole('link')).toBeNull();
  await user.tab();
  await user.keyboard('{Enter}');
  await user.tab();
  const discord = screen.getByRole('link', { name: /Discord/ });
  expect(document.activeElement).toBe(discord);
  expect(discord.getAttribute('href')).toBe('https://discord.gg/sKRrWA5wbf');
  await user.tab();
  const instagram = screen.getByRole('link', { name: /Instagram/ });
  expect(document.activeElement).toBe(instagram);
  expect(instagram.getAttribute('href')).toBe('https://www.instagram.com/findezai/');
  expect(instagram.getAttribute('rel')).toBe('noopener noreferrer');
  await user.keyboard('{Escape}');
  expect(trigger.getAttribute('aria-expanded')).toBe('false');
  expect(document.activeElement).toBe(trigger);
});

test('tap toggles, outside clicks and tabbing away dismiss the menu', async () => {
  const user = userEvent.setup();
  render(<><CommunityMenu /><button>Next</button></>);
  const trigger = screen.getByRole('button', { name: 'Community' });
  const tap = () => user.pointer({ keys: '[TouchA]', target: trigger });
  await tap();
  expect(screen.getAllByRole('link')).toHaveLength(2);
  await tap();
  expect(screen.queryByRole('link')).toBeNull();
  await tap();
  fireEvent.pointerDown(document.body);
  expect(screen.queryByRole('link')).toBeNull();
  await tap();
  await user.tab(); await user.tab(); await user.tab();
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Next' }));
  expect(screen.queryByRole('link')).toBeNull();
});

test('mouse hover opens the menu and leaving closes it', () => {
  render(<CommunityMenu />);
  const root = screen.getByRole('button', { name: 'Community' }).parentElement!;
  const pointer = (type: string) => {
    const event = new Event(type, { bubbles: true });
    Object.defineProperty(event, 'pointerType', { value: 'mouse' });
    fireEvent(root, event);
  };
  pointer('pointerover');
  expect(screen.getAllByRole('link')).toHaveLength(2);
  pointer('pointerout');
  expect(screen.queryByRole('link')).toBeNull();
});
