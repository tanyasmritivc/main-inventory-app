/** @jest-environment jsdom */

import { fireEvent, render, screen } from '@testing-library/react';
import { DemoBooking } from '@/components/demo-booking';

test('requires contact details and confirms only after a saved request, reusing the key on retry', async () => {
  const oldFetch = global.fetch;
  const send = jest.fn()
    .mockRejectedValueOnce(new Error('Network unavailable'))
    .mockResolvedValueOnce({ok: true, status: 202, json: async () => ({status:'received'})});
  global.fetch = send;
  try {
    render(<DemoBooking/>);
    const next = () => fireEvent.click(screen.getByRole('button', {name: 'Continue'}));
    next();
    expect(screen.getByRole('alert').textContent).toBe("Please fill in your name, work email and organization.");
    expect(send).not.toHaveBeenCalled();
    for (const [label,value] of [['Full name','Test Visitor'],['Work email','visitor@example.com'],['Company or organization','Test Lab']]) {
      fireEvent.change(screen.getByRole('textbox', {name: label}), {target:{value}});
    }
    next();
    expect(screen.getByRole('heading', {name: 'Help us tailor your demo.'})).toBe(document.activeElement);
    fireEvent.click(screen.getByRole('button',{name:/BOM comparison/}));
    fireEvent.click(screen.getByRole('button',{name:'Back'}));
    expect(screen.getByDisplayValue('Test Lab')).toBeTruthy();
    next();
    expect(screen.getByRole('button',{name:/BOM comparison/}).getAttribute('aria-pressed')).toBe('true');
    expect(send).not.toHaveBeenCalled();
    const submit = screen.getByRole('button', {name: /Request a demo/});
    fireEvent.click(screen.getByRole('button',{name:/Robotics inventory/}));
    fireEvent.click(submit);
    await screen.findByText(/couldn’t confirm your request/);
    expect(screen.queryByText(/Thanks, Test/)).toBeNull();
    fireEvent.click(submit);
    await screen.findByRole('heading',{name:'Thanks, Test.'});
    expect(send.mock.calls[0][1].body).toEqual(send.mock.calls[1][1].body);
    expect(JSON.parse(send.mock.calls[1][1].body).interests).toEqual(['BOM comparison','Robotics inventory']);
  } finally { global.fetch = oldFetch; }
});
