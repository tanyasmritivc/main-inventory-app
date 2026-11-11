'use strict';
const { randomBytes, timingSafeEqual } = require('node:crypto');
const APP_ORIGIN = 'https://www.findez.ai';
const AUTH_ORIGIN = 'https://findez-db.openstack.ftctools.com';
const PROTOCOL = 'findez-desktop:';
function url(value) { try { return new URL(value); } catch { return null; } }
function trusted(value) { const u=url(value); return !!u && u.origin===APP_ORIGIN && !u.username && !u.password; }
function external(value) { const u=url(value); return !!u && u.protocol==='https:' && !u.username && !u.password; }
function oauth(value) { const u=url(value); return !!u && u.origin===AUTH_ORIGIN && u.pathname==='/auth/v1/authorize' && !u.username && !u.password; }
function safeNext(value) { return typeof value==='string' && value.startsWith('/') && !value.startsWith('//') && !/[\\\u0000-\u001f]/.test(value) ? value : '/worlds'; }
class AuthHandoff {
  constructor({now=Date.now, random=()=>randomBytes(32).toString('base64url')}={}) { this.now=now; this.random=random; this.pending=null; }
  begin(value) {
    if (!oauth(value)) throw new Error('Unsupported sign-in destination.');
    const u=new URL(value), callback=url(u.searchParams.get('redirect_to'));
    if (!callback || !trusted(callback.href) || callback.pathname!=='/auth/callback' || !/^[A-Za-z0-9_-]{43,128}$/.test(u.searchParams.get('code_challenge')||'') || u.searchParams.get('code_challenge_method')?.toLowerCase()!=='s256') throw new Error('Sign-in requires the secure FindEZ PKCE flow.');
    const state=this.random();
    this.pending={state, next:safeNext(callback.searchParams.get('next')), expires:this.now()+10*60*1000};
    const target=new URL('/desktop/callback',APP_ORIGIN);target.searchParams.set('state',state);
    u.searchParams.set('redirect_to',target.href);
    return u.href;
  }
  finish(value) {
    const u=url(value), p=this.pending;
    if (!u || u.protocol!==PROTOCOL || u.hostname!=='auth' || u.pathname!=='/callback' || u.username || u.password || u.port || u.hash || !p) throw new Error('Start sign-in from the FindEZ app first.');
    if ([...u.searchParams.keys()].some(k=>!['state','code','error'].includes(k)) || ['state','code','error'].some(k=>u.searchParams.getAll(k).length>1)) throw new Error('Invalid sign-in response.');
    const state=u.searchParams.get('state')||'';
    if (Buffer.byteLength(state)!==Buffer.byteLength(p.state) || !timingSafeEqual(Buffer.from(state),Buffer.from(p.state)) || this.now()>p.expires) throw new Error('This sign-in request has expired. Start again in FindEZ.');
    const code=u.searchParams.get('code'), error=u.searchParams.get('error');
    if (error || !code || !/^[A-Za-z0-9._~-]{16,512}$/.test(code)) { this.pending=null; throw new Error('Sign-in was not completed. Please try again.'); }
    this.pending=null;
    const target=new URL('/auth/callback',APP_ORIGIN);target.searchParams.set('code',code);target.searchParams.set('next',p.next);
    return target.href;
  }
}
function permissionAllowed(origin, permission) { return trusted(origin) && ['media','notifications'].includes(permission); }
module.exports={APP_ORIGIN,AUTH_ORIGIN,PROTOCOL,trusted,external,oauth,safeNext,AuthHandoff,permissionAllowed};
