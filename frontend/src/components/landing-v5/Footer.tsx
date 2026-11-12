import Link from "next/link";
import { FindEZWordmark } from "@/components/site/findez-brand";

export function Footer({ prefetch }: { prefetch?: false } = {}) {
 return (<footer >
<div className="wrap">
<Link prefetch={prefetch} className="brand" href="/" style={{"fontSize":"17px"}}>
<FindEZWordmark width={96} height={27} />
</Link>

<nav aria-label="Footer navigation">
<Link prefetch={prefetch} href="/solutions">Solutions</Link>
<Link prefetch={prefetch} href="/research">Research</Link>
<Link prefetch={prefetch} href="/pricing">
{"Plans"}
</Link>
<Link prefetch={prefetch} href="/docs/api">
{"Developers"}
</Link>
<Link prefetch={prefetch} href="https://apps.apple.com/us/app/findez-ai/id6760401697">
{"iOS App"}
</Link>
<Link prefetch={prefetch} href="/privacy">
{"Privacy"}
</Link>
<Link prefetch={prefetch} href="/terms">
{"Terms"}
</Link>
<Link prefetch={prefetch} href="mailto:info@findez.ai">
{"Contact"}
</Link>
</nav>

<span >
{"© 2026 AI Robots Inc."}
</span>
</div>
</footer>);
}
