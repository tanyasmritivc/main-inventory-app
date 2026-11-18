'use client';
import { useEffect, useRef, type ReactNode } from 'react';

/** A keyboard-contained card; the scene remains visible but cannot steal shortcuts. */
export function WorldDialog({ title, children, close }: { title: string; children: ReactNode; close(): void }) {
  const ref = useRef<HTMLElement>(null);
  useEffect(() => {
    const before = document.activeElement as HTMLElement | null;
    const element = ref.current;
    element?.focus();
    const key = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { event.stopPropagation(); close(); }
      if (event.key !== 'Tab' || !element) return;
      const controls = [...element.querySelectorAll<HTMLElement>('button:not(:disabled),a[href],input,select,textarea,[tabindex="0"]')];
      const first = controls[0], last = controls.at(-1);
      if (event.shiftKey && (document.activeElement === first || document.activeElement === element)) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === element)) { event.preventDefault(); first?.focus(); }
    };
    element?.addEventListener('keydown', key);
    return () => { element?.removeEventListener('keydown', key); before?.focus(); };
  }, [close]);
  return <><div className="world-modal-shield" /><section ref={ref} className="card world-dialog" role="dialog" aria-modal="true" aria-label={title} tabIndex={-1}>
    <header className="world-dialog-header"><h2>{title}</h2><button className="x" aria-label="Close" onClick={close}>×</button></header><div className="world-dialog-body">{children}</div>
  </section></>;
}
