'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';
import { DemoExamples } from './demo-examples';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const topics = ['AI inventory search', 'Robotics inventory', 'Fusion and STEP models', 'BOM comparison'] as const;
export type DemoTopic = typeof topics[number];

export function DemoExperience() {
  const [interests, setInterests] = useState<DemoTopic[]>([]);
  return <div className={styles.frame}>
    <section aria-labelledby="demo-title">
      <div className={styles.intro}>
        <h1 id="demo-title">See FindEZ<br/>in action.</h1>
        <p>Curious how your team could find parts faster and check a build against what’s on the shelf? Tell us about your team and we will be in touch.</p>
      </div>
      <DemoBooking interests={interests} setInterests={setInterests}/>
    </section>
    <DemoExamples/>
  </div>;
}

export function DemoBooking({interests, setInterests}: {
  interests: DemoTopic[]; setInterests: (next: DemoTopic[]) => void;
}) {
  const [pending, setPending] = useState(false);
  const [thanks, setThanks] = useState<{name: string; email: string} | null>(null);
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
      setError(field?.validity.typeMismatch ? 'Please enter a valid work email.' : 'Please fill in your name, work email and organization.');
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
      setThanks({name: details.name.split(/\s+/)[0], email: details.email});
    } catch {
      setError('We couldn’t confirm your request. Please try again.');
    } finally {
      sending.current = false;
      setPending(false);
    }
  }

  if (thanks) return <div className={styles.thanks}>
    <span aria-hidden="true" className={styles.confirmed}><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="m5 12 5 5 9-10"/></svg></span>
    <h2 ref={heading} tabIndex={-1}>Thanks, {thanks.name}.</h2>
    <p>We will be in touch at {thanks.email} to arrange a walkthrough.</p>
    <a className={styles.back} href="/">Back to findez.ai</a>
  </div>;
  return <form className={styles.form} noValidate onSubmit={submit} onChange={() => setError('')} aria-busy={pending}>
    <div className={styles.row}>
      <label><span>Full name<span className={styles.required} aria-hidden="true">*</span></span><input name="name" placeholder="Alex Chen" autoComplete="name" required pattern=".*\S.*" maxLength={120} disabled={pending}/></label>
      <label><span>Work email<span className={styles.required} aria-hidden="true">*</span></span><input name="email" type="email" placeholder="alex@yourteam.org" autoComplete="email" required maxLength={254} disabled={pending}/></label>
    </div>
    <label><span>Company or organization<span className={styles.required} aria-hidden="true">*</span></span><input name="organization" placeholder="Your team, lab or company" autoComplete="organization" required pattern=".*\S.*" maxLength={180} disabled={pending}/></label>
    <fieldset disabled={pending}>
      <legend>What would you like to explore? <span>(optional)</span></legend>
      <div className={styles.chips}>{topics.map(topic => {
        const selected = interests.includes(topic);
        return <button key={topic} type="button" aria-pressed={selected} onClick={() => setInterests(
          selected ? interests.filter(item => item !== topic) : [...interests, topic]
        )}>{topic}<span aria-hidden="true">{selected ? '✓' : '+'}</span></button>;
      })}</div>
    </fieldset>
    {error && <div role="alert" className={styles.error}>{error}</div>}
    <button type="submit" className={styles.submit} disabled={pending}>{pending ? 'Sending request…' : 'Request a demo'} <span aria-hidden="true">→</span></button>
  </form>;
}
