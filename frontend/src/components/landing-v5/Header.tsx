import { FindEZWordmark } from "@/components/site/findez-brand";

export function Header() {
 return (<header className="nav" id="nav">
<div className="wrap">

<div className="nl">
<a className="brand" href="#hero">
<FindEZWordmark width={96} height={27} />
</a>

<nav className="menu" aria-label="Main">
<a href="#build">
{"Product"}
</a>
<a href="#s4">
{"Solutions"}
</a>
<a href="#s5">
{"Teams"}
</a>
<a href="#s6r">
{"Research"}
</a>
<a href="/docs/api">
{"Developers"}
</a>
<a href="/pricing">
{"Pricing"}
</a>
</nav>
</div>

<nav className="links">
<a className="lg" href="https://apps.apple.com/us/app/findez-ai/id6760401697">
{"iOS App"}
</a>
<a className="lg" href="/signin">
{"Log in"}
</a>
<a className="go" href="/signup">
{"Get started"}
</a>
</nav>

</div>
</header>);
}
