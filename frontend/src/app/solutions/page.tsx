import type { Metadata } from "next";
import Link from "next/link";
import { PagesShell } from "@/components/pages-ui/PagesShell";
import { BlurText, HeroBackdrop, GradientCard, RotatingText } from "@/components/pages-ui/cards";
import type { CSSProperties } from "react";

export const metadata: Metadata = {
 title: "Solutions",
 description: "FindEZ for homes, workshops and robotics, labs and classrooms, and small businesses. Organize belongings, supplies and shared equipment.",
 alternates: { canonical: "/solutions" },
 openGraph: { title: "Solutions | FindEZ", description: "Know what you have. Find it when you need it.", url: "https://findez.ai/solutions" },
};

const solutions = [
 {
  id: "home", audience: "Home", tone: "sunset",
  title: "Find the things you know you own.",
  description: "Give storage boxes, cupboards and household supplies a searchable home. Save locations, quantities, receipts and manuals so the details are there when you need them.",
  example: "Hall closet / Top shelf", items: ["Spare charger", "AA batteries: 12", "LED light bulbs: 4"],
  question: "Where did I put the spare charger?",
  answer: "Your spare charger is in the cable box on the top shelf of the hall closet.",
 },
 {
  id: "workshops", audience: "Workshops & Robotics", tone: "dusk",
  title: "Spend more time building, less time searching.",
  description: "Keep parts, tools and quantities organized by drawer, shelf or bin. Use project kits to check the parts for a build, and low-stock thresholds to see which supplies need attention.",
  example: "Robotics bench / Drawer 2", items: ["M3 screws: 120", "M3 nuts: 80", "USB-C cables: 6"],
  question: "How many M3 screws do we have?",
  answer: "You have 120 M3 screws in Drawer 2 of the robotics bench.",
 },
 {
  id: "labs", audience: "Labs & Classrooms", tone: "sage",
  title: "Keep shared equipment accounted for.",
  description: "Give your lab or classroom one place to find equipment and its records. Manage access, record check-outs and returns, and keep useful documents with each item.",
  example: "Equipment room / Test instruments", items: ["Digital multimeter: checked out", "Bench power supply: available", "Oscilloscope: available"],
  question: "Which equipment is checked out?",
  answer: "The digital multimeter is checked out to Alex and is due back Friday.",
 },
 {
  id: "business", audience: "Small Businesses", tone: "moss",
  title: "Keep the essentials ready for work.",
  description: "Organize supplies and equipment by location, with shared records your team can update. Set quantity thresholds to spot low stock and keep receipts, manuals and notes alongside each item.",
  example: "Studio / Supply cabinet", items: ["Packing tape: 2 rolls", "Mailers: 45", "Shipping labels: 200"],
  question: "What needs restocking?",
  answer: "Packing tape is below your threshold of 3 rolls. There are 2 rolls left in the studio supply cabinet.",
 },
] as const;

export default function SolutionsPage() {
 return <PagesShell page="solutions">
  <main className="public-content">
   <header className="public-intro">
    <HeroBackdrop/>
    <h1><BlurText>Know what you have.<br/>Find it when you need it.</BlurText></h1>
    <RotatingText words={solutions.map(solution => solution.audience)}/>
    <p>Organize belongings, supplies, and shared equipment - from your home to your team&apos;s workspace.</p>
   </header>
   <div className="pages-column">
    <nav className="public-sections" aria-label="On this page">
     {solutions.map(solution => <a href={`#${solution.id}`} key={solution.id}>{solution.audience}</a>)}
    </nav>
    <div className="pages-stack-list">
     {solutions.map((solution,index) => <section className="solution-stack" data-stack style={{"--stack-index":index} as CSSProperties} id={solution.id} aria-label={solution.audience} key={solution.id}>
      <div className="public-split">
       <div className="solution-copy">
        <div className="public-section-heading"><h2>{solution.title}</h2><p>{solution.description}</p></div>
       </div>
       <GradientCard tone={solution.tone}>
        <aside className="public-example" aria-label={`${solution.audience} example`}>
         <h3>{solution.example}</h3>
         <ul className="public-item-list">{solution.items.map(item => <li key={item}>{item}</li>)}</ul>
         <h4>Ask FindEZ</h4>
         <div className="public-question">{solution.question}</div>
         <p>{solution.answer}</p>
         <p className="public-example-note">Illustrative example. Answers use your saved records and available access.</p>
        </aside>
       </GradientCard>
      </div>
     </section>)}
    </div>
    <section className="public-end"><GradientCard tone="moss" className="pages-closing">
     <h2>Start with one Space.</h2>
     <p>Add a few items, save where they belong, and try your first question.</p>
     <div className="public-actions"><Link className="public-primary" href="/signup">Get started</Link></div>
    </GradientCard></section>
   </div>
  </main>
 </PagesShell>;
}
