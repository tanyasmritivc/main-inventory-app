/** @jest-environment jsdom */
import { renderToStaticMarkup } from 'react-dom/server';
import { LandingPage, pageMetadata } from '@/components/marketing-dark/page';
import { FZChat } from '@/components/marketing-dark/chat-runtime';
import { lifecycle } from '@/components/marketing-dark/lifecycle';
import { ORDER, ROUTES, SOL, TITLES, type PageKey } from '@/components/marketing-dark/data';

beforeEach(()=>{
  jest.useFakeTimers();
  Object.defineProperty(window,'matchMedia',{writable:true,value:()=>({matches:false})});
});
afterEach(()=>{jest.useRealTimers();document.body.innerHTML='';});

test.each(Object.keys(TITLES) as PageKey[])('%s renders the source title and real destinations without inline scripts',page=>{
  const html=renderToStaticMarkup(<LandingPage page={page}/>);
  document.body.innerHTML=html;
  expect(pageMetadata(page).title).toEqual({absolute:TITLES[page]});
  expect(document.querySelectorAll('h1')).toHaveLength(1);
  expect(document.querySelectorAll('a[href^="#/"]')).toHaveLength(0);
  expect(document.querySelector('[onclick]')).toBeNull();
  expect(document.querySelector('script')).toBeNull();
  expect(document.querySelector('a[href="/signup"]')).not.toBeNull();
  expect(document.querySelector('a[href="/pricing"]')).not.toBeNull();
  expect(document.querySelector('a[href="https://apps.apple.com/us/app/findez-ai/id6760401697"]')).not.toBeNull();
  expect(document.querySelector('img[src^="data:"]')).toBeNull();
  expect(html).not.toMatch(/[\u2013\u2014]/);
});

test.each(ORDER)('%s renders stable inventory rows and the review draft',key=>{
  document.body.innerHTML=renderToStaticMarkup(<LandingPage page={`sol:${key}`}/>);
  expect(document.querySelectorAll('.ivl>.ir')).toHaveLength(SOL[key].items.slice(0,9).length);
  expect(document.querySelector('.dr .nm')?.textContent).toContain(SOL[key].scene.add[0]);
  expect(document.querySelector('.ivc')?.textContent).toBe('298 items');
  expect(document.querySelector('.is-hit')?.textContent).toContain(SOL[key].scene.hit);
  expect(document.querySelector(`.scard[href="${ROUTES['/'+key]}"]`)).toBeNull();
});

function demo(){
  const host=document.createElement('div'),templates=document.createElement('div');
  templates.innerHTML='<span data-template="mark"><svg></svg></span>'+['p0','p5','p6','wash'].map(k=>`<span data-template="${k}"><img src="/landing/${k}.jpg" alt=""/></span>`).join('');
  document.body.append(host,templates);
  return {host,chat:FZChat(host,{templates})};
}
test('local drafts save only on Save and discarded items stay out of search',()=>{
  const {host,chat}=demo();
  chat.ask('Add 24 copper spacers to Drawer 3');jest.advanceTimersByTime(750);
  expect(host.querySelector('.fz-draft')?.textContent).toContain('Not saved yet');
  (host.querySelector('.fz-draft .p') as HTMLButtonElement).click();
  chat.ask('Where are the copper spacers?');jest.advanceTimersByTime(750);
  expect(host.querySelector('.fz-a:last-child')?.textContent).toContain('Drawer 3');
  chat.ask('Add 2 titanium brackets to Shelf 2');jest.advanceTimersByTime(750);
  (host.querySelector('.fz-draft:last-child .s') as HTMLButtonElement).click();
  chat.ask('Where are the titanium brackets?');jest.advanceTimersByTime(750);
  expect(host.querySelector('.fz-a:last-child')?.textContent).toContain("I can't find that");
  chat.destroy();expect(jest.getTimerCount()).toBe(0);
});
test('demo input is escaped, sheet columns stay intact, capture confidence is ordered',()=>{
  const {host,chat}=demo();chat.ask('<img src=x onerror=alert(1)>');jest.advanceTimersByTime(700);
  expect(host.querySelector('[onerror]')).toBeNull();
  (host.querySelector('[data-k=imp]') as HTMLButtonElement).click();jest.advanceTimersByTime(1800);
  expect(host.querySelector('.fz-sheet .r')?.textContent).toBe('Part #DescriptionQtyLocation');
  (host.querySelector('[data-k=scan]') as HTMLButtonElement).click();jest.advanceTimersByTime(2500);
  expect(Array.from(host.querySelectorAll('.fz-cf')).map(e=>e.textContent)).toEqual(['Confident','Likely','Not sure']);
  expect(host.querySelectorAll('.fz-scan .bx.on')).toHaveLength(3);
  chat.destroy();expect(jest.getTimerCount()).toBe(0);
});
test('unmount cancels pending demo replies and global handlers',()=>{
  const remove=jest.spyOn(document,'removeEventListener');const {host,chat}=demo();
  chat.ask('Where are the M3 screws?');chat.destroy();jest.advanceTimersByTime(3000);
  expect(host.children).toHaveLength(0);expect(remove).toHaveBeenCalledWith('click',expect.any(Function),undefined);
  remove.mockRestore();
});
test('marketing resource lifetime cancels timers, frames, and event listeners',()=>{
  const scope=lifecycle(),fn=jest.fn();scope.timeout(fn,100);scope.interval(fn,100);scope.raf(fn);scope.listen(window,'resize',fn);
  scope.destroy();window.dispatchEvent(new Event('resize'));jest.advanceTimersByTime(500);
  expect(fn).not.toHaveBeenCalled();expect(jest.getTimerCount()).toBe(0);
});
