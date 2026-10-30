"use client";
import {useEffect,useRef} from 'react';
import {createLandingMotion} from './motion';
import {Header} from './Header';
import {Hero} from './Hero';
import {Build} from './Build';
import {Teams} from './Teams';
import {Research} from './Research';
import {Developers} from './Developers';
import {Closing} from './Closing';
import {Footer} from './Footer';
import './landing.css';
export function LandingV5({className=''}:{className?:string}){
 const root=useRef<HTMLDivElement>(null);
 useEffect(()=>{if(root.current)return createLandingMotion(root.current)},[]);
 return <div className={'landing-v5 '+className} ref={root} onClick={e=>{
  const anchor=(e.target as HTMLElement).closest('a[href^="#"]');
  if(anchor){const id=anchor.getAttribute('href');const target=id?root.current?.querySelector(id):null;
   if(target){e.preventDefault();target.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});}}
 }}><Header/><Hero/><main><div className="col"><Build/><Teams/><Research/><Developers/><Closing/></div><Footer/></main></div>;
}
