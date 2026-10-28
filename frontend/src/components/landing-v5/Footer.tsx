import Link from "next/link";
import { FindEZWordmark } from "@/components/site/findez-brand";

export function Footer() {
 return (<footer >
<div className="wrap">
<Link className="brand" href="/" style={{"fontSize":"17px"}}>
<FindEZWordmark width={96} height={27} />
</Link>

<nav aria-label="Footer navigation">
<Link href="/product">Product</Link>
<Link href="/solutions">Solutions</Link>
<Link href="/#s6r">Research</Link>
<Link href="/pricing">
{"Plans"}
</Link>
<Link href="/docs/api">
{"Developers"}
</Link>
<Link href="https://apps.apple.com/us/app/findez-ai/id6760401697">
{"iOS App"}
</Link>
<Link href="/privacy">
{"Privacy"}
</Link>
<Link href="/terms">
{"Terms"}
</Link>
<Link href="mailto:info@findez.ai">
{"Contact"}
</Link>
</nav>

<span >
{"© 2026 AI Robots Inc."}
</span>
</div>
</footer>);
}
