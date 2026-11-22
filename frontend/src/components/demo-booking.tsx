'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const selects = [
  {name: 'type', label: 'Organization type', values: ['Robotics company', 'Engineering or manufacturing team', 'Hardware startup', 'R&D laboratory', 'University or student team', 'Other']},
  {name: 'size', label: 'Team size', values: ['1–10', '11–50', '51–200', '201+']},
  {name: 'interest', label: 'What would you like to explore?', values: ['AI inventory management', 'Robotics team inventory', 'CAD Intelligence and Fusion', 'BOM and inventory comparison', 'Organization-wide deployment', 'Other']},
  {name: 'cad', label: 'Which CAD software does your team use?', values: ['Autodesk Fusion', 'Onshape', 'SolidWorks', 'Other', 'Not currently using CAD']},
] as const;

type Receipt = { when: string; where: string; reschedule?: string };

function confirmedTime(value: unknown) {
  if (typeof value !== 'string' || !/(?:Z|[+-]\d\d:\d\d)$/i.test(value)) return '';
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? new Intl.DateTimeFormat(undefined, {
    weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
    hour: 'numeric', minute: '2-digit', timeZoneName: 'short',
  }).format(date) : '';
}

export function DemoBooking({eventUrl}: {eventUrl: string | null}) {
  const [booking, setBooking] = useState('');
  const [receipt, setReceipt] = useState<Receipt | null>(null);
  const [cad, setCad] = useState('');
  const [error, setError] = useState('');
  const [answers, setAnswers] = useState({email: '', interest: '', zone: ''});
  const calendar = useRef<HTMLIFrameElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const timeHeading = useRef<HTMLHeadingElement>(null);
  const hasAdvanced = useRef(false);

  useEffect(() => {
    if (hasAdvanced.current) (booking ? timeHeading : heading).current?.focus();
  }, [booking, receipt]);

  useEffect(() => {
    if (!booking) return;
    function receive(message: MessageEvent) {
      if (message.origin !== 'https://calendly.com' || message.source !== calendar.current?.contentWindow ||
          message.data?.event !== 'calendly.event_scheduled') return;
      const {event, invitee} = message.data.payload ?? {};
      if (!event?.uri || !invitee?.uri) return;
      const location = event.location?.location || event.location?.join_url;
      const reschedule = invitee.reschedule_url;
      setReceipt({
        when: confirmedTime(event.start_time),
        where: typeof location === 'string' && location ? location : 'Link in your invite',
        reschedule: typeof reschedule === 'string' && /^https:\/\/calendly\.com\/reschedulings\/[\w-]+\/?$/.test(reschedule) ? reschedule : undefined,
      });
    }
    window.addEventListener('message', receive);
    return () => window.removeEventListener('message', receive);
  }, [booking]);

  function chooseTime(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!eventUrl) return;
    const form = event.currentTarget;
    if (!form.checkValidity()) {
      const invalid = form.querySelector<HTMLInputElement | HTMLSelectElement>(':invalid');
      setError(invalid?.validity.typeMismatch ? 'Please enter a valid work email.' : 'Please complete the required fields.');
      invalid?.focus();
      return;
    }
    const fields = new FormData(form);
    const value = (field: string) => String(fields.get(field) ?? '').trim();
    const url = new URL(eventUrl);
    const notes = Object.entries({
      organization: 'Organization', role: 'Role', type: 'Organization type',
      size: 'Team size', interest: 'Demo interest', cad: 'CAD software',
    }).flatMap(([field, label]) => value(field) ? [label + ': ' + value(field)] : []);
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const zoneLabel = new Intl.DateTimeFormat('en', {timeZone: zone, timeZoneName: 'longGeneric'})
      .formatToParts(new Date()).find(part => part.type === 'timeZoneName')?.value || zone;
    Object.entries({
      name: value('name'), email: value('email'), a1: notes.join('\n'),
      embed_domain: window.location.hostname, embed_type: 'Inline', timezone: zone,
      background_color: '1b1b1b', text_color: 'f3f1ea', primary_color: 'f3f1ea',
      hide_event_type_details: '1', hide_gdpr_banner: '1',
    }).forEach(([key, setting]) => url.searchParams.set(key, setting));
    setAnswers({email: value('email'), interest: value('interest'), zone: zoneLabel});
    hasAdvanced.current = true;
    setBooking(url.href);
  }

  if (!eventUrl) return <><h2>Book your personalized demo</h2><p>Online scheduling is being set up. You can reach the team directly about a demonstration in the meantime.</p><a href="mailto:info@findez.ai?subject=FindEZ%20product%20demo">Email the FindEZ team</a></>;
  return <>
    <div hidden={!!booking}>
      <small>20 minutes · Live online</small>
      <h2 ref={heading} tabIndex={-1}>Book your personalized demo</h2>
      <p>Tell us about your team, then choose a time.</p>
      <form className={styles.form} noValidate onSubmit={chooseTime} onChange={() => setError('')}>
        <label>Full name<input autoComplete="name" name="name" required maxLength={120} pattern=".*\S.*" /></label>
        <label>Work email<input autoComplete="email" name="email" type="email" required maxLength={254} /></label>
        <label>Company or organization<input autoComplete="organization" name="organization" required maxLength={180} pattern=".*\S.*" /></label>
        <label>Job title or role<input autoComplete="organization-title" name="role" required maxLength={120} pattern=".*\S.*" /></label>
        {selects.map(field => {
          const optional = field.name === 'cad' || field.name === 'size';
          return <label key={field.name} className={field.name === 'interest' || field.name === 'cad' ? styles.wide : undefined}>
            <span>{field.label}{optional && <span className={styles.optional}> (optional)</span>}</span>
            <select name={field.name} required={!optional} defaultValue="" onChange={field.name === 'cad' ? e => setCad(e.target.value) : undefined}>
              <option value="">Select</option>
              {field.values.map(value => <option key={value} value={value}>{value.replaceAll('–', ' to ')}</option>)}
            </select>
          </label>;
        })}
        {['Onshape', 'SolidWorks', 'Other'].includes(cad) && <div className={styles.note}>FindEZ integrates with Autodesk Fusion today. We’ll show how teams on other tools use FindEZ alongside their CAD.</div>}
        {error && <div role="alert" className={styles.error}>{error}</div>}
        <button type="submit" className={styles.button}>Choose a date and time <span aria-hidden="true">→</span></button>
      </form>
    </div>
    {booking && <>
      {receipt ? <>
        <span aria-hidden="true" className={styles.confirmed}>✓</span>
        <h2 ref={timeHeading} tabIndex={-1}>You’re booked.</h2>
        <p>A calendar invite is on its way to {answers.email}.</p>
        <dl className={styles.details}>
          {receipt.when && <><dt>When</dt><dd>{receipt.when}</dd></>}
          <dt>Where</dt><dd>{receipt.where}</dd><dt>Focus</dt><dd>{answers.interest}</dd>
        </dl>
        {receipt.reschedule && <a className={styles.back} href={receipt.reschedule}>Reschedule</a>}
      </> : <>
        <small>20 minutes · {answers.zone}</small>
        <h2 ref={timeHeading} tabIndex={-1}>Pick a time</h2>
      </>}
      {/* Calendly can send only resource URIs. Keep its real receipt visible for the appointment details. */}
      <iframe ref={calendar} className={styles.calendar} title="FindEZ demo booking calendar" src={booking} referrerPolicy="strict-origin" />
      {!receipt && <div className={styles.actions}>
        <button type="button" className={styles.back} onClick={() => setBooking('')}>Back</button>
        <a href={booking} target="_blank" rel="noopener noreferrer">Open calendar in a new tab</a>
      </div>}
    </>}
  </>;
}
