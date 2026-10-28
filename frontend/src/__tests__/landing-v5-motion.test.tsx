/** @jest-environment jsdom */
import {act, fireEvent, render, screen} from '@testing-library/react';
import {Build} from '@/components/landing-v5/Build';
import {Audiences} from '@/components/landing-v5/Audiences';
import {createLandingMotion} from '@/components/landing-v5/motion';
let nextFrame: FrameRequestCallback;
let reduced=false, pinned=true, top=0;
beforeEach(()=>{
 jest.useFakeTimers(); reduced=false;pinned=true;top=0;
 Object.defineProperty(window,'matchMedia',{writable:true,value:()=>({matches:reduced})});
 jest.spyOn(window,'requestAnimationFrame').mockImplementation(callback=>{nextFrame=callback;return 1});
 jest.spyOn(window,'cancelAnimationFrame').mockImplementation(()=>{});
 jest.spyOn(window,'getComputedStyle').mockImplementation(()=>({position:pinned?'sticky':'relative'}) as CSSStyleDeclaration);
 Object.defineProperty(window,'innerHeight',{value:900,configurable:true});
});
afterEach(()=>{jest.useRealTimers();jest.restoreAllMocks()});
function setup(){
 const view=render(<div><div id="nav"/><Build/><div id="findC"/><div id="closeC"/></div>);
 const root=view.container;
 root.querySelector('#build')!.getBoundingClientRect=()=>({top,height:4000}) as DOMRect;
 const stop=createLandingMotion(root);
 const advance=()=>act(()=>{for(let i=0;i<90;i++)nextFrame(i*16)});
 return {root,stop,advance};
}
test('scrolling completes and reverses the inventory story; unmount cancels the frame',()=>{
 const {root,stop,advance}=setup();advance();
 expect(root.querySelector('#um1 .t')!.textContent?.trim()).toBe('');
 top=-3200;advance();
 expect(root.querySelector('#tED .tu')!.textContent).toBe('7');
 expect((root.querySelector('#saved') as HTMLElement).style.opacity).toBe('1');
 top=0;advance();
 expect(root.querySelector('#tED .tu')!.textContent).toBe('5');
 expect((root.querySelector('#saved') as HTMLElement).style.opacity).toBe('0');
 stop();expect(cancelAnimationFrame).toHaveBeenCalled();expect(root.dataset.motion).toBeUndefined();
});
test.each(['reduced motion','stacked mobile'])('%s shows the finished story without waiting for scroll',mode=>{
 reduced=mode==='reduced motion';pinned=mode!=='stacked mobile';
 const {root,stop,advance}=setup();advance();
 expect(root.querySelector('#tED .tu')!.textContent).toBe('7');
 expect((root.querySelector('#saved') as HTMLElement).style.opacity).toBe('1');
 expect(root.querySelector('#um2 .t')!.textContent).toBe('Add 2 more multimeters to the electronics drawer.');stop();
});
test('audience rotation stops after selection and cleans up on unmount',()=>{
 jest.spyOn(window,'getComputedStyle').mockRestore();
 const view=render(<Audiences/>);
 view.container.querySelector('section')!.getBoundingClientRect=()=>({top:0,bottom:800}) as DOMRect;
 act(()=>jest.advanceTimersByTime(4900));
 expect(screen.getByRole('button',{name:'Labs and classrooms'}).getAttribute('aria-pressed')).toBe('true');
 fireEvent.click(screen.getByRole('button',{name:'Homes'}));act(()=>jest.advanceTimersByTime(300));
 act(()=>jest.advanceTimersByTime(15000));
 expect(screen.getByRole('button',{name:'Homes'}).getAttribute('aria-pressed')).toBe('true');
 view.unmount();expect(jest.getTimerCount()).toBe(0);
});
