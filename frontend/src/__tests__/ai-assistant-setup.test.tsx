/** @jest-environment jsdom */
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AiAssistantSetup, assistantInstructions } from '@/components/site/ai-assistant-setup';

test('assistant setup exposes both downloads, full inventory permissions and platform limits', () => {
  render(<AiAssistantSetup />);
  expect(screen.getByRole('heading', { name: 'Connect Claude or ChatGPT' })).toBeTruthy();
  expect(screen.getByRole('link', { name: 'Download the FindEZ Desktop extension' }).getAttribute('href')).toBe('/docs/api/findez-inventory.mcpb');
  expect(screen.getByRole('link', { name: 'download the Actions schema' }).getAttribute('href')).toBe('/docs/api/chatgpt-actions.json');
  expect(screen.getByText('Create and update items')).toBeTruthy();
  expect(screen.getByText('Bulk import')).toBeTruthy();
  expect(screen.getByText('Neither includes a delete action.')).toBeTruthy();
  expect(screen.getByText('Only me')).toBeTruthy();
  expect(screen.getByText('Desktop chat')).toBeTruthy();
});

test('copies schema URL and instructions without asking for or embedding a real key', async () => {
  const user = userEvent.setup();
  const copy = jest.spyOn(navigator.clipboard, 'writeText').mockResolvedValue();
  const { container } = render(<AiAssistantSetup />);
  await user.click(screen.getByRole('button', { name: 'Copy ChatGPT Actions schema URL' }));
  expect(copy).toHaveBeenLastCalledWith('https://findez.ai/docs/api/chatgpt-actions.json');
  await user.click(screen.getByRole('button', { name: 'Copy FindEZ assistant instructions' }));
  expect(copy).toHaveBeenLastCalledWith(assistantInstructions);
  expect(assistantInstructions).toContain('Do not simulate deletion');
  expect(assistantInstructions).toContain('obtain confirmation');
  expect(container.querySelector('input')).toBeNull();
  expect(container.textContent).not.toMatch(/findez_(live|test)_sk_[A-Za-z0-9_-]{32}/);
});
