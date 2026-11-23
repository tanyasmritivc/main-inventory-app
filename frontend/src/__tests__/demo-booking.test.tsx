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
    expect(screen.getByRole('alert').textContent).toBe("Please complete the required fields.");
    expect(send).not.toHaveBeenCalled();
    for (const [label,value] of [['Full name','Test Visitor'],['Work email','visitor@example.com'],['Company or organization','Test Lab'],['Job title or role','Engineer']]) {
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
    expect(screen.getByRole('alert').textContent).toBe('Please complete the required fields.');
    expect(send).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText(/What best describes/), {target:{value:'Hardware startup'}});
    fireEvent.change(screen.getByLabelText(/How did you hear/), {target:{value:'A colleague'}});
    fireEvent.click(screen.getByRole('button',{name:'Other'}));
    fireEvent.change(screen.getByRole('textbox',{name:/Tell us what else/}), {target:{value:'Parts traceability'}});
    fireEvent.click(submit);
    await screen.findByText(/couldn’t confirm your request/);
    expect(screen.queryByText(/Thanks for requesting a demo/)).toBeNull();
    fireEvent.click(submit);
    await screen.findByRole('heading',{name:'Thanks for requesting a demo.'});
    expect(screen.getByText('We will be in touch to arrange a walkthrough.')).toBeTruthy();
    expect(document.body.textContent).not.toMatch(/Test Visitor|visitor@example\.com/);
    expect(send.mock.calls[0][1].body).toEqual(send.mock.calls[1][1].body);
    expect(JSON.parse(send.mock.calls[1][1].body).interests).toEqual(['BOM comparison','Robotics inventory']);
  } finally { global.fetch = oldFetch; }
});
