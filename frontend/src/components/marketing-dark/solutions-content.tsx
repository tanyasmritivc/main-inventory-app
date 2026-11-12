// Server-rendered copy and sample questions from the supplied Solutions prototype.
export function SolutionsHero(){return (<section className={"s-hero"}><div className={"x-in"}>
<h1 className={"s-h1"}>{"A better way to find what you already have."}<span >{"Parts, tools, equipment and supplies, for teams that build things."}</span></h1>
<div className={"x-ctas"}><a className={"x-p w lg"} href={"/signup"}>{"Get Free Founders Access"}</a><a className={"x-p d lg"} href={"#sm"}>{"See how it works"}</a></div>
<div className={"s-ins"} id={"s-ins"}>
<div className={"s-tabs"} role={"tablist"}><button className={"s-tab on"} role={"tab"} aria-selected={"true"}>{"Robotics teams"}</button><button className={"s-tab"} role={"tab"} aria-selected={"false"}>{"Workshops"}</button><button className={"s-tab"} role={"tab"} aria-selected={"false"}>{"Makerspaces"}</button><button className={"s-tab"} role={"tab"} aria-selected={"false"}>{"Engineering labs"}</button></div>
<div className={"s-body"}>
<div className={"s-chat"}><div className={"s-k"}>{"ASK"}</div><div className={"s-q"} id={"s-q"}>{"Where are the 24 tooth HTD pulleys?"}</div>
<div className={"s-k"} style={{"marginTop": "26px"}}>{"RESOLVED PATH"}</div>
<div className={"s-path"}><div className={"s-pn"}><span className={"mono"}>{"SPACE"}</span><span id={"p0"}>{"Robotics Lab"}</span></div><div className={"s-pn"}><span className={"mono"}>{"STORAGE"}</span><span id={"p1"}>{"Parts wall"}</span></div><div className={"s-pn"}><span className={"mono"}>{"BIN"}</span><span id={"p2"}>{"Bin PN-F260"}</span></div><div className={"s-pn"}><span className={"mono"}>{"ITEM"}</span><span id={"p3"}>{"5mm HTD pulley ×18"}</span></div></div>
<div className={"s-a"} id={"s-a"}></div></div>
<div className={"s-gw"}><canvas id={"s-graph"} aria-hidden={"true"}></canvas></div>
</div>
<div className={"s-foot"}><span id={"s-stat"}>{"inventory map"}</span><span className={"s-fr"}><span >{"Sample data"}</span><a className={"s-more"} id={"s-more"} href={"/solutions/robotics"}>{"Robotics teams"}<svg width={"12"} height={"12"} viewBox={"0 0 24 24"} fill={"none"} stroke={"currentColor"} strokeWidth={"2.2"} strokeLinecap={"round"} strokeLinejoin={"round"}><path d={"M5 12h14M13 6l6 6-6 6"}></path></svg></a></span></div>
</div>
</div></section>);}
const audiences = [
  {name: 'Robotics teams', tags: 'FTC · FRC · ROBOTICS CLUBS', headline: 'Less time searching for parts. More time building robots.', description: 'Keep track of electronics, components, tools and spare parts. Bring existing team records into FindEZ and ask what your team has when you need it.', href: '/solutions/robotics', link: 'Explore Robotics teams'},
  {name: 'Workshops & machine shops', tags: 'CNC · 3D PRINTING · TOOLING', headline: 'Inventory that doesn’t depend on someone’s memory.', description: 'Make tooling, accessories, consumables and replacement parts easier to record and search.', href: '/solutions/workshops', link: 'Explore Workshops'},
  {name: 'Makers & makerspaces', tags: 'ELECTRONICS · MATERIALS · SHARED TOOLS', headline: 'Components and supplies, within reach.', description: 'Make electronics, materials, tools and shared equipment easier to keep track of.', href: '/solutions/makerspaces', link: 'Explore Makerspaces'},
  {name: 'Engineering labs', tags: 'COMPONENTS · EQUIPMENT · SUPPLIES', headline: 'Shared inventory, easier to find.', description: 'Keep records of lab components, equipment, supplies and materials in one searchable inventory.', href: '/solutions/engineering-labs', link: 'Explore Engineering labs'},
];
export function AudienceCards(){return <section className="x-sec"><div className="x-in">
  <h2 className="x-h2">Built around the places where things get lost.<span>Four kinds of teams. One way to find things.</span></h2>
  <div className="s-audience-grid">{audiences.map(a=><article className="s-audience-card" key={a.href}>
    <div className="who">{a.name}</div><div className="tags">{a.tags}</div>
    <h3>{a.headline}</h3><p>{a.description}</p>
    <a className="go" href={a.href}>{a.link}<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a>
  </article>)}</div>
</div></section>;}
export function InventoryMorph(){return (<section className={"sm"} id={"sm"}><div className={"sm-st"}><canvas id={"smc"} aria-hidden={"true"}></canvas>
<div className={"sm-cp"}><h2 className={"x-h2"}>{"One inventory."}<span >{"Scroll to see it come together."}</span></h2>
<div className={"sm-ph"}><div className={"sm-r on"}><div className={"t"}>{"Bring what you already have"}</div><div className={"d"}>{"Import a supported spreadsheet. Column names stay as they are."}</div></div>
<div className={"sm-r"}><div className={"t"}>{"See it as places"}</div><div className={"d"}>{"Every row lands in the bin or Space where it’s kept."}</div></div>
<div className={"sm-r"}><div className={"t"}>{"Ask FindEZ"}</div><div className={"d"}>{"Answers come from what’s recorded, down to the bin."}</div></div></div></div>
</div></section>);}
export function SolutionsEnd(){return (<div className={"s-end"}></div>);}
