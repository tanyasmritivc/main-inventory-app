/** @jest-environment jsdom */
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ItemPhotoGallery } from '@/components/site/item-photo-gallery';
import { accountRequest } from '@/lib/account-request';
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'test' }) }));
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/private-image', () => ({ privateImageSrc: (url: string) => url }));
beforeEach(() => {
  jest.mocked(accountRequest).mockReset().mockResolvedValue({ photos: [
    { photo_id: 'a', image_url: '/portrait.jpg', is_primary: true },
    { photo_id: 'b', image_url: '/landscape.jpg', is_primary: false },
  ] });
});
test('preview switches photos, opens the selected full image and restores keyboard focus on Escape', async () => {
  const user = userEvent.setup();
  render(<ItemPhotoGallery itemId="i" canEdit />);
  await screen.findByRole('button', { name: 'Open item photo 1, primary' });
  await user.click(screen.getByRole('button', { name: 'Select item photo 2' }));
  const preview = screen.getByRole('button', { name: 'Open item photo 2' });
  await user.click(preview);
  const viewer = screen.getByRole('dialog', { name: 'Item photo' });
  expect(within(viewer).getByAltText('Full item photo').getAttribute('src')).toBe('/landscape.jpg');
  await user.keyboard('{Escape}');
  expect(screen.queryByRole('dialog')).toBeNull();
  expect(document.activeElement).toBe(preview);
  expect(accountRequest).toHaveBeenCalledTimes(1);
});
test('deleting still requires confirmation and cancelling keeps the full image and photos', async () => {
  const user = userEvent.setup();
  render(<ItemPhotoGallery itemId="i" canEdit />);
  await user.click(await screen.findByRole('button', { name: 'Open item photo 1, primary' }));
  await user.click(screen.getByRole('button', { name: 'Delete photo' }));
  const confirm = screen.getByRole('dialog', { name: 'Delete this photo?' });
  await user.click(within(confirm).getByRole('button', { name: 'Cancel' }));
  expect(screen.getByRole('dialog', { name: 'Item photo' })).toBeTruthy();
  expect(accountRequest).toHaveBeenCalledTimes(1);
});
