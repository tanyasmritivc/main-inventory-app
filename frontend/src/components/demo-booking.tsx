'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';
import { DemoSearch } from './demo-search';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const topics = ['AI inventory search', 'Robotics inventory', 'Fusion and STEP models', 'BOM comparison'] as const;
export type DemoTopic = typeof topics[number];

export function DemoExperience() {
  const [interests, setInterests] = useState<DemoTopic[]>([]);
  return <div className={styles.columns}>
    <section className={styles.story}>
      <h1>See FindEZ<br/>in action.</h1>
      <p className={styles.intro}>Follow a part from the shelf to an engineering design. See how your team finds what’s on hand and checks what a build still needs.</p>
      <DemoSearch topic={interests.at(-1)} />
      <h2>What you’ll see</h2>
      <ul>
        <li>Find a part, its quantity and its location with AI search.</li>
        <li>Share inventory across teams and spaces.</li>
        <li>Work in Autodesk Fusion and generate a custom STEP model.</li>
        <li>Compare a bill of materials with available stock.</li>
      </ul>
      <a className={styles.pilot} href="mailto:info@findez.ai?subject=FindEZ%20organization%20pilot%20request">Request an Organization Pilot <span aria-hidden="true">↗</span></a>
    </section>
    <section className={styles.panel} aria-label="Request a demo">
      <DemoBooking interests={interests} setInterests={setInterests}/>
    </section>
  </div>;
}

export function DemoBooking({interests, setInterests}: {
  interests: DemoTopic[]; setInterests: (next: DemoTopic[]) => void;
}) {
  const [pending, setPending] = useState(false);
  const [thanks, setThanks] = useState('');
  const [error, setError] = useState('');
  const heading = useRef<HTMLHeadingElement>(null);
  const sending = useRef(false);
  const lastRequest = useRef({body: '', id: ''});
  useEffect(() => { if (thanks) heading.current?.focus(); }, [thanks]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (sending.current) return;
    const form = event.currentTarget;
    if (!form.checkValidity()) {
      const field = form.querySelector<HTMLInputElement>('input:invalid');
      setError(field?.validity.typeMismatch ? 'Please enter a valid work email.' : 'Please complete the required fields.');
      field?.focus();
      return;
    }
    const data = new FormData(form);
    const value = (key: string) => String(data.get(key) ?? '').trim();
    const details = {name: value('name'), email: value('email'), organization: value('organization'), interests};
    const body = JSON.stringify(details);
    sending.current = true;
    setPending(true);
    setError('');
    try {
      if (lastRequest.current.body !== body) lastRequest.current = {body, id: crypto.randomUUID()};
      const base = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000';
      const response = await fetch(base + '/demo-requests', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({...details, request_id: lastRequest.current.id}),
        signal: AbortSignal.timeout(20000),
      });
      if (response.status === 429) { setError('Too many requests. Please try again later.'); return; }
      if (response.status === 422) { setError('Please check your name, work email, and organization.'); return; }
      if (!response.ok || (await response.json()).status !== 'received') throw new Error();
      setThanks(details.name.split(/\s+/)[0]);
    } catch {
      setError('We couldn’t confirm your request. Please try again.');
    } finally {
      sending.current = false;
      setPending(false);
    }
  }

  if (thanks) return <>
    <span aria-hidden="true" className={styles.confirmed}>✓</span>
    <h2 ref={heading} tabIndex={-1}>Thanks, {thanks}.</h2>
    <p>We’ve received your demo request. We will email you to arrange a time.</p>
    <a className={styles.explore} href="/">Explore FindEZ <span aria-hidden="true">↗</span></a>
  </>;
  return <>
    <h2>Request a demo</h2>
    <p>Tell us about your team. Tanya will be in touch to arrange a walkthrough.</p>
    <form className={styles.form} noValidate onSubmit={submit} onChange={() => setError('')} aria-busy={pending}>
      <label>Full name<input name="name" autoComplete="name" required pattern=".*\S.*" maxLength={120} disabled={pending}/></label>
      <label>Work email<input name="email" type="email" autoComplete="email" required maxLength={254} disabled={pending}/></label>
      <label className={styles.wide}>Company or organization<input name="organization" autoComplete="organization" required pattern=".*\S.*" maxLength={180} disabled={pending}/></label>
      <fieldset className={styles.interests} disabled={pending}>
        <legend>What would you like to explore? <span className={styles.optional}>(optional)</span></legend>
        <div className={styles.chips}>{topics.map(topic => {
          const selected = interests.includes(topic);
          return <button key={topic} type="button" aria-pressed={selected} onClick={() => setInterests(
            selected ? interests.filter(item => item !== topic) : [...interests, topic]
          )}>{topic}<span aria-hidden="true">{selected ? '×' : '+'}</span></button>;
        })}</div>
      </fieldset>
      {error && <div role="alert" className={styles.error}>{error}</div>}
      <button type="submit" className={styles.button} disabled={pending}>{pending ? 'Sending request…' : 'Request a demo'} <span aria-hidden="true">→</span></button>
    </form>
  </>;
}
