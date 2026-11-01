import { FIND_RESEARCH as research } from "@/lib/find-research";

export function Research() {
 return (<section className="sec" id="s6r">

<div className="two">
<div data-rv="">
<h2 >
{"Building FIND"}
</h2>
</div>

<div data-rv="">
<p className="p">
{research.introduction}
</p>

<div className="btns" style={{"marginTop":"22px"}}>
<a className="btn w" href={research.contactHref}>
{research.contactLabel}
</a>
</div>
</div>
</div>

<div className="find grain g-dusk" id="findC" data-rv="">

<div className="fb" style={{"left":"52%","top":"12%","width":"20%","height":"28%"}}>
<i >
{research.labels[0]}
</i>
</div>

<div className="fb" style={{"left":"77%","top":"8%","width":"17%","height":"22%"}}>
<i >
{research.labels[1]}
</i>
</div>

<div className="fb" style={{"left":"66%","top":"46%","width":"15%","height":"16%"}}>
<i >
{research.labels[2]}
</i>
</div>

<div className="fhead">
<h3 >
{research.heading[0]}
<br  />
{research.heading[1]}
</h3>
</div>

<div className="pillars">
{research.pillars.map(([label, title, detail], i) => (
<div key={title}>
<em className={i === 0 ? "now" : undefined}>{label}</em>
<b>{title}</b>
<span>{detail}</span>
</div>
))}
</div>

</div>

<p className="note">
{research.status}
</p>

<p className="note">{research.invitation}</p>

<span className="tick l">

</span>
<span className="tick r">

</span>

</section>);
}
