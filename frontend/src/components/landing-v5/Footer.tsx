import { FindEZWordmark } from "@/components/site/findez-brand";

export function Footer() {
 return (<footer >
<div className="wrap">
<a className="brand" href="#hero" style={{"fontSize":"17px"}}>
<FindEZWordmark width={96} height={27} />
</a>

<nav aria-label="Footer navigation">
<a href="/pricing">
{"Plans"}
</a>
<a href="/docs/api">
{"Developers"}
</a>
<a href="https://apps.apple.com/us/app/findez-ai/id6760401697">
{"iOS App"}
</a>
<a href="/privacy">
{"Privacy"}
</a>
<a href="/terms">
{"Terms"}
</a>
<a href="mailto:info@findez.ai">
{"Contact"}
</a>
</nav>

<span >
{"© 2026 AI Robots Inc."}
</span>
</div>
</footer>);
}
