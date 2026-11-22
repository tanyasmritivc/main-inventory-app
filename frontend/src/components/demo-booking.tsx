'use client';

import { useState, type FormEvent } from 'react';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const selects = [
  {name: 'type', label: 'Organization type', values: ['Robotics company', 'Engineering or manufacturing team', 'Hardware startup', 'R&D laboratory', 'University or student team', 'Other']},
  {name: 'size', label: 'Team size (optional)', values: ['1–10', '11–50', '51–200', '201+']},
  {name: 'interest', label: 'What would you like to explore?', values: ['AI inventory management', 'Robotics team inventory', 'CAD Intelligence and Fusion', 'BOM and inventory comparison', 'Organization-wide deployment', 'Other']},
  {name: 'cad', label: 'Which CAD software does your team use? (optional)', values: ['Autodesk Fusion', 'Onshape', 'SolidWorks', 'Other', 'Not currently using CAD']},
] as const;

export function DemoBooking({eventUrl}: {eventUrl: string | null}) {
  const [booking, setBooking] = useState('');
  function chooseTime(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!eventUrl) return;
    const fields = new FormData(event.currentTarget);
    const url = new URL(eventUrl);
    url.searchParams.set('name', String(fields.get('name')).trim());
    url.searchParams.set('email', String(fields.get('email')).trim());
    // The published event has one free-text preparation question.
    const notes = Object.entries({
      organization: 'Organization', role: 'Role', type: 'Organization type',
      size: 'Team size', interest: 'Demo interest', cad: 'CAD software',
    }).flatMap(([field, label]) => {
      const value = String(fields.get(field) || '').trim();
      return value ? [label + ': ' + value] : [];
    });
    url.searchParams.set('a1', notes.join('\n'));
    url.searchParams.set('embed_domain', window.location.hostname);
    url.searchParams.set('embed_type', 'Inline');
    setBooking(url.href);
  }
  if (!eventUrl) return <><p>Online scheduling is being set up. You can reach the team directly about a demonstration in the meantime.</p><a href="mailto:info@findez.ai?subject=FindEZ%20product%20demo">Email the FindEZ team</a></>;
  return <>
    <div hidden={!!booking}>
      <p>Tell us about your team, then choose a time for your walkthrough.</p>
      <form className={styles.form} onSubmit={chooseTime}>
        <label>Full name<input autoComplete="name" name="name" required maxLength={120} pattern=".*\S.*" /></label>
        <label>Work email<input autoComplete="email" name="email" type="email" required maxLength={254} /></label>
        <label>Company or organization<input autoComplete="organization" name="organization" required maxLength={180} pattern=".*\S.*" /></label>
        <label>Job title or role<input autoComplete="organization-title" name="role" required maxLength={120} pattern=".*\S.*" /></label>
        {selects.map(field => <label key={field.name} className={['interest','cad'].includes(field.name) ? styles.wide : undefined}>{field.label}
          <select name={field.name} required={field.name === 'type' || field.name === 'interest'} defaultValue="">
            <option value="">Select an option</option>
            {field.values.map(value => <option key={value}>{value}</option>)}
          </select>
        </label>)}
        <button type="submit" className={styles.button}>Choose a date and time →</button>
      </form>
    </div>
    {booking && <div>
      <p>Choose an available time and confirm your booking in the calendar.</p>
      <button type="button" className={styles.edit} onClick={() => setBooking('')}>Edit your details</button>
      <iframe className={styles.calendar} title="FindEZ demo booking calendar" src={booking} referrerPolicy="strict-origin" />
      <a href={booking} target="_blank" rel="noopener noreferrer">Open calendar in a new tab</a>
    </div>}
  </>;
}
