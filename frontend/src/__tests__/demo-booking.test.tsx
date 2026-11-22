/** @jest-environment jsdom */
import { fireEvent, render, screen } from '@testing-library/react';
import { DemoBooking } from '@/components/demo-booking';
import { calendlyEvent } from '@/lib/demo-scheduling';

test('only a secure Calendly event enables scheduling', () => {
  expect(calendlyEvent('https://calendly.com/findez/demo/?track=x')).toBe('https://calendly.com/findez/demo');
  for (const value of [undefined, 'https://meet.google.com/room', 'http://calendly.com/findez/demo',
    'https://calendly.com/findez', 'https://calendly.com/app/scheduling']) expect(calendlyEvent(value)).toBeNull();
  render(<DemoBooking eventUrl={null}/>);
  expect(screen.queryByTitle('FindEZ demo booking calendar')).toBeNull();
  expect(screen.getByRole('link', {name:'Email the FindEZ team'}).getAttribute('href')).toMatch(/^mailto:/);
});

test('qualification passes to the calendar, and editing preserves the visitor’s answers', () => {
  render(<DemoBooking eventUrl="https://calendly.com/findez/demo"/>);
  const company = screen.getByLabelText('Company or organization');
  expect((company as HTMLInputElement).required).toBe(true);
  for (const [label, value] of [['Full name', 'Taylor Smith'],['Work email', 'taylor@example.org'],
    ['Company or organization','Lab & Co'],['Job title or role','Engineer'],['Organization type','R&D laboratory'],
    ['What would you like to explore?', 'BOM and inventory comparison']]) {
    fireEvent.change(screen.getByLabelText(label), {target:{value}});
  }
  fireEvent.click(screen.getByRole('button',{name:/Choose a date/}));
  const url=new URL(screen.getByTitle('FindEZ demo booking calendar').getAttribute('src')!);
  expect(url.origin).toBe('https://calendly.com');
  expect(url.searchParams.get('a1')?.split('\n')).toEqual([
    'Organization: Lab & Co', 'Role: Engineer', 'Organization type: R&D laboratory',
    'Demo interest: BOM and inventory comparison',
  ]);
  expect(url.searchParams.get('a4')).toBeNull();
  fireEvent.click(screen.getByRole('button',{name:'Edit your details'}));
  expect((company as HTMLInputElement).value).toBe('Lab & Co');
});
