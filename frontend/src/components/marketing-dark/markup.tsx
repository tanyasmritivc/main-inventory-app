import { createElement, type CSSProperties, type ReactNode } from 'react';
import Image from 'next/image';
import { FindEZMark } from '@/components/site/findez-brand';
import { BENCH, EXT, FZ_IMG, ROUTES, SOL, type Audience, type DemoItem } from './data';
import { ChatDemo } from './chat-demo';

// This parser only accepts the checked-in marketing templates, never user input.
// It renders ordinary React nodes on the server, including Next images and islands.
type Node = { tag: string; attrs: Record<string, string>; children: (Node | string)[] };
const decode = (s: string) => s.replace(/&(amp|lt|gt|quot|apos|nbsp|#39);/g, (_, key: string) => ({amp:'&',lt:'<',gt:'>',quot:'"',apos:"'",nbsp:'\u00a0','#39':"'"}[key] || ''));
const camel = (s: string) => s.replace(/-([a-z])/g, (_, c: string) => c.toUpperCase());
function style(value = ''): CSSProperties {
  return Object.fromEntries(value.split(';').filter(Boolean).map(d => {
    const i = d.indexOf(':'); const k = d.slice(0,i).trim();
    return [k.startsWith('--') ? k : camel(k), d.slice(i+1).trim()];
  }));
}
export function Brand({size = 24}: {size?: number}) {
  return <span className="brand-slot dark"><FindEZMark width={size} height={size}/></span>;
}
export function SceneInventory({audience}: {audience: Audience}) {
  const s = SOL[audience];
  function row(item: DemoItem, i: number, draft = false) {
    const low = !draft && item.q <= item.low;
    return <div key={`${draft ? 'draft' : i}`} className={`ir${draft?' nw':''}${item.n===s.scene.hit?' is-hit':''}${low?' is-low':''}`} style={{'--r':i} as CSSProperties}>
      <span className="nm"><i>{item.img ? <Image src={FZ_IMG[item.img]} alt="" fill sizes="32px" unoptimized style={{objectFit:'cover'}}/> : <svg className="i" viewBox="0 0 24 24"><path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5Z"/><path d="M3 7.5 12 12l9-4.5M12 12v9"/></svg>}</i><span>{item.n}</span>{draft&&<span className="tg">Draft</span>}{low&&<span className="lw">Low</span>}</span>
      <span className="lc">{item.loc}</span><span className="q">{item.q}</span>
    </div>;
  }
  const [n,loc,q] = s.scene.add;
  return <><div className="sweep"/><div className="dr"><div>{row({n,loc,q:Number(q),low:-1},0,true)}</div></div>{s.items.slice(0,9).map((r,i)=>row(r,i+1))}</>;
}
export function Markup({html, audience='robotics'}: {html: string; audience?: Audience}) {
  const root:Node = {tag:'div',attrs:{},children:[]}; const stack=[root];
  const tokens = html.match(/<!--[\s\S]*?-->|<[^>]+>|[^<]+/g) || [];
  for (const token of tokens) {
    if(token.startsWith('<!--')) continue;
    if(token.startsWith('</')) { stack.pop(); continue; }
    if(!token.startsWith('<')) {stack[stack.length-1].children.push(decode(token));continue;}
    const name = token.match(/^<([\w-]+)/)?.[1]; if(!name) continue;
    const attrs:Record<string,string>={};
    for(const m of token.slice(name.length+1).matchAll(/([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) attrs[m[1]]=decode(m[2]??m[3]??m[4]??'');
    const node:Node={tag:name,attrs,children:[]}; stack[stack.length-1].children.push(node);
    if(!/\/$/.test(token.slice(0,-1))&&!['img','br','hr','input','meta','link'].includes(name))stack.push(node);
  }
  function render(node: Node|string, key: number):ReactNode {
    if(typeof node==='string')return node;
    const a=node.attrs; const props:Record<string,unknown>={key};
    if('data-brand' in a)return <Brand key={key} size={+a['data-brand']}/>;
    if('data-chat' in a)return <ChatDemo key={key} audience={audience}/>;
    for(const [k,v] of Object.entries(a)) {
      if(k==='onclick') {
        const ext=v.match(/ext\('([^']+)'\)/)?.[1] as keyof typeof EXT|undefined;
        if(ext)props.href=EXT[ext];
        else if(v.includes('mnav('))props['data-menu']=v.includes('mnav(1)')?'open':'close';
        else if(v.includes("classList.toggle('open')")){props['data-faq']='';props['aria-expanded']=false;}
        else if(v.includes('[data-chap]'))props['data-chapter-start']='';
      } else if(k==='class')props.className=v;
      else if(k==='style')props.style=style(v);
      else if(k==='href')props.href=v.startsWith('#/')?ROUTES[v.slice(1)]??v:v;
      else if(k==='tabindex')props.tabIndex=+v;
      else props[k.startsWith('data-')||k.startsWith('aria-')?k:camel(k)]=v;
    }
    let children:ReactNode = node.children.map(render);
    if(a.id==='lg'||a.id==='lg2')children=<Brand size={a.id==='lg'?24:22}/>;
    if(a.class==='ivl')children=<SceneInventory audience={audience}/>;
    if(a.class==='wsbg'||a.class==='ph') {
      const styles = props.style as CSSProperties|undefined;
      if(styles)delete styles.backgroundImage;
      children=<Image src={BENCH} alt="" fill sizes="100vw" unoptimized className="asset-photo"/>;
    }
    if(a.class?.split(' ').includes('ix'))props.id=a.href==='#/robotics'?'teams':a.href.slice(2);
    if('data-ck' in a){props.href=`#team-${a['data-ck']}`;}
    if('data-chapter-start' in props)props.href='#by-team';
    if('data-chap' in a)props.id='by-team';
    return ['img','br','hr','input','meta','link'].includes(node.tag)?createElement(node.tag,props):createElement(node.tag,props,children);
  }
  return <>{root.children.map(render)}</>;
}
