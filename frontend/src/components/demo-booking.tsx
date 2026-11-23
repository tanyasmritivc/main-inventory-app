'use client';

import { useEffect, useRef, useState, type FormEvent } from 'react';
import { DemoExamples } from './demo-examples';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const topics = ['AI inventory search', 'Robotics inventory', 'Fusion and STEP models', 'BOM comparison'] as const;
type DemoTopic = (typeof topics)[number];
const organizationTypes = ['Robotics team', 'Robotics company', 'Hardware startup', 'Engineering or manufacturing company', 'University or research lab', 'Makerspace or workshop', 'School', 'Other'];
const teamSizes = ['1 to 10', '11 to 50', '51 to 200', '201 to 1,000', '1,000+'];
const cadTools = ['Autodesk Fusion', 'Onshape', 'SolidWorks', 'Other', "We don't use CAD"];

function Marker({required = false}: {required?: boolean}) {
  return required
    ? <span className={styles.required} aria-hidden="true">*</span>
    : <span className={styles.optional}> (optional)</span>;
}

function SelectField({label, name, options, required = false}: {
  label: string; name: string; options: string[]; required?: boolean;
}) {
  return <label>
    <span>{label}<Marker required={required}/></span>
    <span className={styles.selectWrap}>
      <select name={name} required={required} defaultValue="">
        <option value="">Select</option>
        {options.map(option => <option key={option}>{option}</option>)}
      </select>
    </span>
  </label>;
}

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
  const [other, setOther] = useState(false);
  const [pending, setPending] = useState(false);
  const [thanks, setThanks] = useState(false);
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
      const field = form.querySelector<HTMLInputElement | HTMLSelectElement>('input:invalid, select:invalid');
      setError(field?.validity.typeMismatch ? 'Please enter a valid work email.' : 'Please complete the required fields.');
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
      setThanks(true);
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
    <h2 ref={heading} tabIndex={-1}>Thanks for requesting a demo.</h2>
    <p>We will be in touch to arrange a walkthrough.</p>
    <a className={styles.back} href="/">Back to findez.ai</a>
  </div> : <form className={styles.form} noValidate onSubmit={submit} onChange={() => setError('')} aria-busy={pending}>
    <fieldset className={styles.fields} hidden={stage !== 'contact'} disabled={stage !== 'contact' || pending}>
      <div className={styles.row}>
        <label><span>Full name<Marker required/></span><input name="name" placeholder="Alex Chen" autoComplete="name" required pattern=".*\S.*" maxLength={120}/></label>
        <label><span>Work email<Marker required/></span><input name="email" type="email" placeholder="alex@yourteam.org" autoComplete="email" required maxLength={254}/></label>
      </div>
      <div className={styles.row}>
        <label><span>Company or organization<Marker required/></span><input name="organization" placeholder="Your team, lab or company" autoComplete="organization" required pattern=".*\S.*" maxLength={180}/></label>
        <label><span>Job title or role<Marker required/></span><input name="role" placeholder="e.g. Build lead" autoComplete="organization-title" required pattern=".*\S.*"/></label>
      </div>
    </fieldset>
    <fieldset className={styles.fields} hidden={stage !== 'questions'} disabled={stage !== 'questions' || pending}>
      <div className={styles.row}>
        <SelectField label="What best describes your organization?" name="organizationType" options={organizationTypes} required/>
        <SelectField label="Team size" name="teamSize" options={teamSizes}/>
      </div>
      <label><span>How did you hear about FindEZ?<Marker required/></span><input name="referral" required pattern=".*\S.*" placeholder="e.g. Instagram, a friend, a competition"/></label>
      <fieldset>
        <legend>What would you like to explore?<Marker/></legend>
        <div className={styles.chips}>
          {topics.map(topic => {
            const selected = interests.includes(topic);
            return <button key={topic} type="button" aria-pressed={selected} onClick={() => setInterests(
              selected ? interests.filter(item => item !== topic) : [...interests, topic]
            )}>{topic}<span aria-hidden="true">{selected ? '✓' : '+'}</span></button>;
          })}
          <button type="button" aria-pressed={other} aria-controls="demo-other-interest" onClick={() => setOther(!other)}>
            Other<span aria-hidden="true">{other ? '✓' : '+'}</span>
          </button>
        </div>
        <input id="demo-other-interest" name="otherInterest" hidden={!other} disabled={!other}
          aria-label="Tell us what else you'd like to see" placeholder="Tell us what else you'd like to see"/>
      </fieldset>
      <SelectField label="Which CAD software does your team use?" name="cadSoftware" options={cadTools}/>
      <label><span>What are you trying to solve?<Marker/></span>
        <textarea name="problem" rows={4} placeholder="For example: we keep rebuying parts we already have, or we want to check a Fusion assembly before ordering."/>
      </label>
    </fieldset>
    {error && <div role="alert" className={styles.error}>{error}</div>}
    <div className={styles.actions}>
      {stage === 'questions' && <button className={styles.back} type="button" disabled={pending} onClick={() => changeStage('contact')}>Back</button>}
      <button type="submit" className={styles.submit} disabled={pending}>{stage === 'contact' ? 'Continue' : pending ? 'Sending request…' : 'Request a demo'} <span aria-hidden="true">→</span></button>
    </div>
  </form>}
  </section>;
}
