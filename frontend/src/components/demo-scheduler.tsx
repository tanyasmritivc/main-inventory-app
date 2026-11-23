'use client';

import { useEffect, useRef, useState } from 'react';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

type Meeting = {state: 'offered'|'confirmed'|'completed'|'cancelled', starts: number|null,
  slots: number[], minutes: number, location: string|null, revision: number};
async function scheduling(action: string, fields: object): Promise<Meeting> {
  const token = window.location.hash.slice(1);
  if (!token) throw new Error('Open the private scheduling link in your invitation.');
  const base = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000';
  const response = await fetch(base + '/demo-scheduling/' + action, {
    method:'POST', headers:{'Content-Type':'application/json'}, cache:'no-store',
    signal: AbortSignal.timeout(20000), body: JSON.stringify({token, ...fields}),
  });
  if (response.status === 404) throw new Error('This scheduling link is no longer available. Reply to your invitation for new times.');
  if (response.status === 409) throw new Error('Availability changed. Refresh the times and choose again.');
  if (!response.ok) throw new Error('We couldn’t confirm the appointment details. Please refresh and try again.');
  return response.json();
}

export function DemoScheduler() {
  const [meeting, setMeeting] = useState<Meeting|null>(null);
  const [zone, setZone] = useState('UTC');
  const [selected, select] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(true);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const sending = useRef(false);
  useEffect(() => {
    let current = true;
    setZone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
    scheduling('view', {}).then(m => { if (current) setMeeting(m); })
      .catch(e => { if (current) setError(e.message); })
      .finally(() => { if (current) setBusy(false); });
    return () => { current = false; };
  }, []);
  async function update(action: 'view'|'book'|'cancel') {
    if (sending.current) return;
    sending.current = true; setBusy(true); setError('');
    try {
      const fields = action === 'view' ? {} : {revision:meeting?.revision, ...(action === 'book' ? {starts:Number(selected), zone} : {})};
      setMeeting(await scheduling(action, fields));
      setConfirmCancel(false); select('');
    } catch (e) { setError(e instanceof Error ? e.message : 'Please try again.'); }
    finally { sending.current = false; setBusy(false); }
  }
  const format = (seconds: number) => new Intl.DateTimeFormat(undefined, {dateStyle:'full', timeStyle:'short', timeZone:zone}).format(seconds*1000);
  const active = meeting?.state === 'offered' || meeting?.state === 'confirmed';
  const canChange = active && (!meeting.starts || meeting.starts > Date.now()/1000);
  return <section className={styles.frame} style={{display:'block', maxWidth:720, margin:'0 auto', background:'white'}}>
    <header className={styles.intro}><h1>Your FindEZ demo</h1></header>
    <div className={styles.form} aria-busy={busy}>
      {meeting?.state === 'confirmed' && meeting.starts && <div role="status"><h2>Meeting confirmed</h2>
        <p>{format(meeting.starts)} ({zone}) · {meeting.minutes} minutes</p>
        {meeting.location && <a className={styles.back} href={meeting.location} rel="noreferrer">Join meeting</a>}</div>}
      {meeting?.state === 'cancelled' && <p>This appointment has been cancelled. Reply to your invitation for new times.</p>}
      {meeting?.state === 'completed' && <p>This demo is complete.</p>}
      {canChange && <fieldset disabled={busy} className={styles.fields}>
        <label>{meeting.state === 'confirmed' ? 'Choose a different time' : 'Choose a time'} ({zone})
          <select value={selected} onChange={e => select(e.target.value)}><option value="">Select an available time</option>
            {meeting.slots.filter(t=>t!==meeting.starts).map(t=><option key={t} value={t}>{format(t)}</option>)}</select></label>
        {!meeting.slots.some(t=>t!==meeting.starts) && <p>Reply to your invitation to request more times.</p>}
        <button className={styles.submit} disabled={!selected} onClick={()=>update('book')}>{meeting.state==='confirmed'?'Confirm new time':'Confirm meeting'}</button>
        {meeting.state==='confirmed' && (confirmCancel ? <><p>Cancel this appointment and notify the organizer?</p>
          <button className={styles.back} onClick={()=>update('cancel')}>Yes, cancel appointment</button>
          <button className={styles.back} onClick={()=>setConfirmCancel(false)}>Keep appointment</button></> :
          <button className={styles.back} onClick={()=>setConfirmCancel(true)}>Cancel appointment</button>)}
      </fieldset>}
      {busy && <p role="status">Checking appointment details…</p>}
      {error && <p role="alert">{error}</p>}
      <button className={styles.back} disabled={busy} onClick={()=>update('view')}>Refresh times</button>
    </div></section>;
}
