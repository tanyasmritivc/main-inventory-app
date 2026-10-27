/** @jest-environment jsdom */
import { act, render, screen } from '@testing-library/react';
import { ChatProgress } from '@/components/site/chat-progress';

test('keeps real activity in a native accessible disclosure', () => {
  const { rerender, container } = render(<ChatProgress message="Finding objects…" />);
  expect(container.querySelector('details')?.hasAttribute('open')).toBe(false);
  rerender(<ChatProgress message="Checking confidence…" />);
  expect(screen.getByRole('status').textContent).toContain('Checking confidence...');
  expect(screen.getByRole('list', { name: 'Activity so far', hidden: true }).textContent).toContain('Finding objects...');
  expect(container.querySelectorAll('li')).toHaveLength(2);
  rerender(<ChatProgress message="Checking confidence…" />);
  expect(container.querySelectorAll('li')).toHaveLength(2);
});


test('shows elapsed time, actual liveness and stale updates without inventing work', () => {
  jest.useFakeTimers();
  jest.setSystemTime(new Date('2026-10-26T04:00:00Z'));
  const start = Date.now();
  const { rerender, unmount, container } = render(<ChatProgress message="Thinking through your request..." startedAt={start} />);
  expect(screen.getByRole('timer').textContent).toContain('0s elapsed · Waiting for server updates');
  act(() => jest.advanceTimersByTime(65000));
  expect(screen.getByRole('timer').textContent).toContain('1m 5s elapsed · Waiting for server updates');
  rerender(<ChatProgress message="Thinking through your request..." startedAt={start} lastActivityAt={Date.now()} />);
  expect(screen.getByRole('timer').textContent).toContain('Receiving updates');
  act(() => jest.advanceTimersByTime(30000));
  expect(screen.getByRole('timer').textContent).toContain('Last update 30s ago');
  expect(container.querySelectorAll('li')).toHaveLength(1);
  expect(screen.getByRole('timer').getAttribute('aria-live')).toBe('off');
  unmount();
  expect(jest.getTimerCount()).toBe(0);
  jest.useRealTimers();
});

test('keeps a server-reported retry visible when the next phase arrives', () => {
  const { rerender } = render(<ChatProgress message="Retrying the interrupted response..." />);
  rerender(<ChatProgress message="Building your item draft..." />);
  expect(screen.getByRole('timer').textContent).toContain('Second attempt');
  expect(screen.getByRole('status').textContent).toContain('Building your item draft...');
});


test('groups repeated real phases, bounds history, and retains retry evidence', () => {
  const view = render(<ChatProgress message="Retrying the interrupted response..." />);
  for (let i=0;i<8;i++) {
    view.rerender(<ChatProgress message="Searching your saved items…" />);
    view.rerender(<ChatProgress message="Working through the results..." />);
  }
  expect(view.container.querySelectorAll('li')).toHaveLength(3);
  expect(view.container.querySelectorAll('li')[2].textContent).toContain('8 updates');
  expect(view.container.querySelectorAll('li[aria-current="step"]')).toHaveLength(1);
  for (let i=0;i<10;i++) view.rerender(<ChatProgress message={`Actual phase ${i}`} />);
  expect(view.container.querySelectorAll('li')).toHaveLength(6);
  expect(screen.getByRole('timer').textContent).toContain('Second attempt');
});
