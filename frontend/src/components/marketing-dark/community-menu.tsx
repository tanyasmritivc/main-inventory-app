'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { ChevronDown } from 'lucide-react';

export function CommunityMenu() {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const hovered = useRef(false);
  const panelId = useId();

  useEffect(() => {
    if (!open) return;
    const dismiss = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener('pointerdown', dismiss);
    return () => document.removeEventListener('pointerdown', dismiss);
  }, [open]);

  return <div className="community" ref={root}
    onPointerEnter={event => {
      hovered.current = event.pointerType === 'mouse';
      if (hovered.current) setOpen(true);
    }}
    onPointerLeave={event => {
      hovered.current = false;
      if (event.pointerType === 'mouse' && !event.currentTarget.contains(document.activeElement)) setOpen(false);
    }}
    onBlur={event => { if (!event.currentTarget.contains(event.relatedTarget)) setOpen(false); }}
    onKeyDown={event => {
      if (event.key === 'Escape' && open) {
        event.preventDefault();
        event.stopPropagation();
        setOpen(false);
        trigger.current?.focus();
      }
    }}>
    <button ref={trigger} type="button" className="community-trigger" aria-expanded={open}
      aria-controls={panelId} onClick={event => setOpen(value => event.detail > 0 && hovered.current ? true : !value)}>
      Community <ChevronDown size={14} aria-hidden="true" />
    </button>
    <div id={panelId} className="community-panel" hidden={!open}>
      <div className="community-links">
        <a href="https://discord.gg/sKRrWA5wbf" target="_blank" rel="noopener noreferrer">
          <span><strong>Discord</strong></span>
          <span className="community-sr"> (opens in a new tab)</span>
        </a>
        <a href="https://www.instagram.com/findezai/" target="_blank" rel="noopener noreferrer">
          <span><strong>Instagram</strong></span>
          <span className="community-sr"> (opens in a new tab)</span>
        </a>
      </div>
    </div>
  </div>;
}
