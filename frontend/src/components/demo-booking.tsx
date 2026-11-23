'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';
import { DemoExamples } from './demo-examples';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const questions = [
  {label: 'Which inventory workflows would you like to see?', topics: ['AI inventory search', 'Robotics inventory']},
  {label: 'Which CAD workflows should we cover?', topics: ['Fusion and STEP models', 'BOM comparison']},
] as const;
type DemoTopic = (typeof questions)[number]['topics'][number];

export function DemoExperience() {
  return <div className={styles.frame}>
    <DemoBooking/>
    <DemoExamples/>
  </div>;
}

export function DemoBooking() {
  const [stage, setStage] = useState<'contact' | 'questions'>('contact');
  const [contact, setContact] = useState({name: '', email: '', organization: ''});
  const [interests, setInterests] = useState<DemoTopic[]>([]);
  const [pending, setPending] = useState(false);
  const [thanks, setThanks] = useState<{name: string; email: string} | null>(null);
  const [error, setError] = useState('');
  const heading = useRef<HTMLHeadingElement>(null);
  const sending = useRef(false);
  const lastRequest = useRef({body: '', id: ''});
  const focusNext = useRef(false);
  useEffect(() => {
    if (focusNext.current || thanks) heading.current?.focus();
    focusNext.current = false;
  }, [stage, thanks]);

  function changeStage(next: typeof stage) {
    focusNext.current = true;
    setError('');
    setStage(next);
  }

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
    if (stage === 'contact') {
      const data = new FormData(form);
      const value = (key: string) => String(data.get(key) ?? '').trim();
      setContact({name: value('name'), email: value('email'), organization: value('organization')});
      changeStage('questions');
      return;
    }
    const details = {...contact, interests};
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

  return <section aria-labelledby="demo-title">
    <div className={styles.intro}>
      <h1 id="demo-title" tabIndex={-1} ref={thanks ? undefined : heading}>
        {stage === 'questions' && !thanks ? 'Help us tailor your demo.' : <>See FindEZ<br/>in action.</>}
      </h1>
      <p>{stage === 'questions' && !thanks
        ? 'Choose any topics that matter to your team. We’ll use your answers to prepare your walkthrough.'
        : 'Curious how your team could find parts faster and check a build against what’s on the shelf? Tell us about your team and we will be in touch.'}</p>
    </div>
    {thanks ? <div className={styles.thanks}>
    <span aria-hidden="true" className={styles.confirmed}><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="m5 12 5 5 9-10"/></svg></span>
    <h2 ref={heading} tabIndex={-1}>Thanks, {thanks.name}.</h2>
    <p>We will be in touch at {thanks.email} to arrange a walkthrough.</p>
    <a className={styles.back} href="/">Back to findez.ai</a>
  </div> : <form key={stage} className={styles.form} noValidate onSubmit={submit} onChange={() => setError('')} aria-busy={pending}>
    {stage === 'contact' ? <>
    <div className={styles.row}>
      <label><span>Full name<span className={styles.required} aria-hidden="true">*</span></span><input defaultValue={contact.name} name="name" placeholder="Alex Chen" autoComplete="name" required pattern=".*\S.*" maxLength={120} disabled={pending}/></label>
      <label><span>Work email<span className={styles.required} aria-hidden="true">*</span></span><input defaultValue={contact.email} name="email" type="email" placeholder="alex@yourteam.org" autoComplete="email" required maxLength={254} disabled={pending}/></label>
    </div>
    <label><span>Company or organization<span className={styles.required} aria-hidden="true">*</span></span><input defaultValue={contact.organization} name="organization" placeholder="Your team, lab or company" autoComplete="organization" required pattern=".*\S.*" maxLength={180} disabled={pending}/></label>
    </> : questions.map(question => <fieldset key={question.label} disabled={pending}>
      <legend>{question.label} <span>(optional)</span></legend>
      <div className={styles.chips}>{question.topics.map(topic => {
        const selected = interests.includes(topic);
        return <button key={topic} type="button" aria-pressed={selected} onClick={() => setInterests(
          selected ? interests.filter(item => item !== topic) : [...interests, topic]
        )}>{topic}<span aria-hidden="true">{selected ? '✓' : '+'}</span></button>;
      })}</div>
    </fieldset>)}
    {error && <div role="alert" className={styles.error}>{error}</div>}
    <div className={styles.actions}>
      {stage === 'questions' && <button className={styles.back} type="button" disabled={pending} onClick={() => changeStage('contact')}>Back</button>}
      <button type="submit" className={styles.submit} disabled={pending}>{stage === 'contact' ? 'Continue' : pending ? 'Sending request…' : 'Request a demo'} <span aria-hidden="true">→</span></button>
    </div>
  </form>}
  </section>;
}
