import { Children, Fragment, type CSSProperties, type ReactNode } from "react";

export function BlurText({children}:{children:ReactNode}) {
 let index=0;
 return <>{Children.map(children, child => typeof child === "string" ? child.split(/(\s+)/).map((word,i)=>/^\s+$/.test(word) ? <Fragment key={i}>{word}</Fragment> : <span className="blur-word" data-word={index++} key={i}>{word}</span>) : child)}</>;
}
export function HeroBackdrop(){return <div className="pages-hero-bg grain" aria-hidden="true"><i/><i/><i/></div>;}
export function GradientCard({children,tone="sunset",className=""}:{children:ReactNode;tone?:string;className?:string}){return <div className={`pages-gradient grain g-${tone} ${className}`} data-loop data-reveal>{children}</div>;}
export function SpotlightCard({children,icon}:{children:ReactNode;icon?:ReactNode}){return <article className="pages-spotlight" data-spotlight data-reveal>{icon&&<span className="pages-icon" aria-hidden="true">{icon}</span>}{children}</article>;}
export function RotatingText({words}:{words:readonly string[]}){return <div className="pages-rotate grain g-sunset" data-rotate data-loop aria-hidden="true">{words.map((word,i)=><span key={word} style={{opacity:i===0?1:0,position:i===0?"relative":"absolute"} as CSSProperties}>{word}</span>)}</div>;}
export function TypedQuestion({text}:{text:string}){return <><span className="pages-sr-only">{text}</span><span aria-hidden="true" data-type={text}>{text}</span></>;}
