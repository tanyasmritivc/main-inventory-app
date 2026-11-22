/** @jest-environment jsdom */

import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { DemoBooking, type DemoTopic } from '@/components/demo-booking';

function Example() {
  const [interests, setInterests] = useState<DemoTopic[]>([]);
  return <DemoBooking interests={interests} setInterests={setInterests}/>;
}

test('requires contact details and confirms only after a saved request, reusing the key on retry', async () => {
  const oldFetch = global.fetch;
  const send = jest.fn()
    .mockRejectedValueOnce(new Error('Network unavailable'))
    .mockResolvedValueOnce({ok: true, status: 202, json: async () => ({status:'received'})});
  global.fetch = send;
  try {
    render(<Example/>);
    const submit = screen.getByRole('button', {name: /Request a demo/});
    fireEvent.click(submit);
    expect(screen.getByRole('alert').textContent).toMatch(/required/);
    expect(send).not.toHaveBeenCalled();
    for (const [label,value] of [['Full name','Test Visitor'],['Work email','visitor@example.com'],['Company or organization','Test Lab']]) {
      fireEvent.change(screen.getByLabelText(label), {target:{value}});
    }
    fireEvent.click(screen.getByRole('button',{name:/BOM comparison/}));
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
