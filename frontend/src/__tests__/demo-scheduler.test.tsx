/** @jest-environment jsdom */
import {fireEvent, render, screen} from '@testing-library/react';
import {DemoScheduler} from '@/components/demo-scheduler';

const starts = 2100000000;
const initial = {state:'offered', slots:[starts], starts:null, minutes:30, revision:1};
const booked = {...initial,state:'confirmed',starts,revision:2,location:'https://meet.example.test/room'};
const ok = (body: object) => ({ok:true,status:200,json:async()=>body});
test('shows confirmation only after booking and requires a separate cancellation confirmation',async()=>{
  window.location.hash = 'private-scheduling-fixture';
  const original = global.fetch;
  const fetcher = jest.fn().mockResolvedValueOnce(ok(initial)).mockResolvedValueOnce(ok(booked))
    .mockResolvedValueOnce(ok({...booked,state:'cancelled',location:null}));
  global.fetch=fetcher;
  try {
    render(<DemoScheduler/>);
    const times=await screen.findByRole('combobox');
    expect(screen.queryByRole('heading',{name:'Meeting confirmed'})).toBeNull();
    fireEvent.change(times,{target:{value:String(starts)}});
    fireEvent.click(screen.getByRole('button',{name:'Confirm meeting'}));
    await screen.findByRole('heading',{name:'Meeting confirmed'});
    expect(fetcher.mock.calls[1][0]).not.toContain(window.location.hash.slice(1));
    expect(JSON.parse(fetcher.mock.calls[1][1].body)).toMatchObject({token:window.location.hash.slice(1),revision:1,starts});
    fireEvent.click(screen.getByRole('button',{name:'Cancel appointment'}));
    expect(fetcher).toHaveBeenCalledTimes(2);
    fireEvent.click(screen.getByRole('button',{name:'Yes, cancel appointment'}));
    await screen.findByText(/This appointment has been cancelled/);
    expect(screen.queryByRole('link',{name:'Join meeting'})).toBeNull();
  } finally {global.fetch=original;window.location.hash='';}
});
