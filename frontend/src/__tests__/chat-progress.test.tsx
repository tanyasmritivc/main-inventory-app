/** @jest-environment jsdom */
import { render, screen } from '@testing-library/react';
import { ChatProgress } from '@/components/site/chat-progress';

test('keeps real activity in a native accessible disclosure', () => {
  const { rerender, container } = render(<ChatProgress message="Finding objects…" />);
  expect(container.querySelector('details')?.hasAttribute('open')).toBe(false);
  rerender(<ChatProgress message="Checking confidence…" />);
  expect(screen.getByRole('status').textContent).toContain('Checking confidence…');
  expect(screen.getByRole('list', { name: 'Activity so far', hidden: true }).textContent).toContain('Finding objects…');
  expect(container.querySelectorAll('li')).toHaveLength(2);
  rerender(<ChatProgress message="Checking confidence…" />);
  expect(container.querySelectorAll('li')).toHaveLength(2);
});
