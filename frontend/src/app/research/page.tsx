import type { Metadata } from "next";
import { PagesShell } from "@/components/pages-ui/PagesShell";
import { BlurText, HeroBackdrop, GradientCard } from "@/components/pages-ui/cards";

export const metadata:Metadata={title:"Research",description:"Building FIND: visual perception today, with learning, adaptation and robot support as research goals.",alternates:{canonical:"/research"}};
const statement="FIND is AI Robots Inc.'s proprietary AI pipeline for understanding the physical world. It starts with visual perception inside FindEZ and works toward robots that learn new tasks and adapt to unfamiliar environments with less task-specific training.";
const pillars=[['Current focus','Perception','Objects, labels, barcodes and counts from images.'],['Research','Learning','Learning from demonstrations and feedback.'],['Research','Adaptation','Less retraining for each new task or place.'],['Research','Robot-agnostic','Designed to work across robot platforms.']];
export default function ResearchPage(){return <PagesShell page="research"><main>
 <header className="public-intro"><HeroBackdrop/><h1><BlurText>Building FIND</BlurText></h1><div className="public-actions"><a className="public-primary" href="mailto:info@findez.ai?subject=FIND%20research%20partnership">Partner with us</a></div></header>
 <div className="pages-column"><section className="public-section"><p className="research-intro-copy" data-scroll-words>{statement.split(/(\s+)/).map((word,i)=><span key={i}>{word}</span>)}</p></section>
 <section className="public-section"><GradientCard tone="ember" className="research-road"><h2>Robots that learn.<br/>Not just robots that follow.</h2><div className="research-labels"><span>object · 0.97</span><span>label · DC18RC</span><span>count · 14</span></div><div className="research-pillars">{pillars.map(([label,title,detail],i)=><article key={title}><em className={i===0?"current-dot":undefined}>{label}</em><h3>{title}</h3><p>{detail}</p></article>)}</div></GradientCard><p className="public-note">FIND is in active development. Learning, adaptation and robot support are research goals, not shipped features.</p></section></div>
 </main></PagesShell>;}
