import { Suspense } from 'react';
import { WorldGate } from '@/components/world/world-gate';
export default function WorldPage() {
  return <Suspense fallback={<div className="fz-world"><div className="world-start">Opening your world...</div></div>}><WorldGate /></Suspense>;
}
