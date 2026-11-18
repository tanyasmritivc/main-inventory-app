'use client';
import { useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { signInPath } from '@/lib/auth-paths';
import { selectInventory, requireInventoryContext } from '@/lib/inventory-selection';
import { WorldClient } from './world-client';

declare global { interface Window { FindEZApp?: { postMessage(message: string): void } } }

export function WorldGate() {
  const params = useSearchParams(), router = useRouter();
  const embedded = params.get('embed') === '1';
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [account, setAccount] = useState<string | null>(null), [error, setError] = useState('');
  useEffect(() => {
    let active = true, bridged = !embedded;
    selectInventory(null); requireInventoryContext(false);
    const read = async () => {
      const { data, error: failure } = await supabase.auth.getSession();
      if (!active) return;
      if (failure) { setError('Your session could not be checked. Reopen World and try again.'); return; }
      if (bridged) setAccount(data.session?.user.id || null);
      if (!data.session && !embedded) router.replace(signInPath('/world'));
    };
    const receive = async (event: MessageEvent) => {
      if (!embedded || !window.FindEZApp || event.source !== window || event.origin !== window.location.origin) return;
      const value = event.data;
      if (value?.type !== 'fz-session' || typeof value.access_token !== 'string' || typeof value.refresh_token !== 'string') return;
      if (value.access_token.length > 16000 || value.refresh_token.length > 16000) return;
      const { error: failure } = await supabase.auth.setSession({ access_token: value.access_token, refresh_token: value.refresh_token });
      if (active && failure) setError('World could not connect to your app session. Close it and try again.');
      else if (active) { bridged = true; setError(''); await read(); }
    };
    window.addEventListener('message', receive);
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      if (active && bridged) {
        setAccount(session?.user.id || null);
        if (_event === 'SIGNED_OUT' && !embedded) router.replace(signInPath('/world'));
      }
    });
    void read();
    if (embedded) window.FindEZApp?.postMessage('ready');
    return () => { active = false; window.removeEventListener('message', receive); subscription.subscription.unsubscribe(); };
  }, [supabase, router, embedded]);
  if (!account) return <div className="fz-world"><div className="world-start" role="status">{error || (embedded ? 'Connecting to your FindEZ app...' : 'Opening your world...')}{error && <button className="btn" onClick={() => window.location.reload()}>Try again</button>}</div></div>;
  return <WorldClient key={account} accountId={account} embedded={embedded} />;
}
