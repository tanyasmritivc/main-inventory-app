'use client';
import { useEffect, useRef, type ReactNode } from 'react';
import { mountMotion } from './motion-runtime';
import type { PageKey } from './data';
export function Motion({page, children}: {page:PageKey; children:ReactNode}) {
  const ref=useRef<HTMLDivElement>(null);
  useEffect(()=>{if(ref.current)return mountMotion(ref.current,page)},[page]);
  return <div className="landing-dark" ref={ref}>{children}</div>;
}
