import Link from "next/link";
import { ArrowDownToLine, ArrowUpRight, BookOpen, KeyRound } from "lucide-react";
import { apiEndpoints, API_BASE, DOCS_UPDATED, endpointCurl, guideSections, type DocSection } from "@/lib/api-docs";
import { CodeExample, PrintDocumentation } from "./api-docs-controls";
import styles from "./api-documentation.module.css";

function GuideSection({ section }: { section: DocSection }) {
  return <section id={section.id} className={styles.section} aria-labelledby={`${section.id}-title`}>
    <h2 id={`${section.id}-title`}>{section.title}<a href={`#${section.id}`} aria-label={`Link to ${section.title}`}>#</a></h2>
    {section.paragraphs.map(paragraph => <p key={paragraph}>{paragraph}</p>)}
    {section.steps && <ol>{section.steps.map(step => <li key={step}>{step}</li>)}</ol>}
    {section.table && <div className={styles.tableScroll} tabIndex={0} role="region" aria-label={`${section.title} reference table`}>
      <table><thead><tr>{section.table.columns.map(column => <th scope="col" key={column}>{column}</th>)}</tr></thead>
        <tbody>{section.table.rows.map(row => <tr key={row[0]}>{row.map((cell, index) => index === 0 ? <th scope="row" key={index}>{cell}</th> : <td key={index}>{cell}</td>)}</tr>)}</tbody>
      </table>
    </div>}
    {section.codes?.map(code => <CodeExample key={code.label} {...code} />)}
    {section.note && <aside className={styles.note}><strong>Keep in mind</strong><p>{section.note}</p></aside>}
  </section>;
}

export function ApiDocumentation() {
  const startingSections = guideSections.slice(0, 3);
  const remainingSections = guideSections.slice(3);
  return <div className={styles.page}>
    <a href="#documentation-content" className={styles.skipLink}>Skip to documentation</a>
    <header className={styles.topbar}>
      <div><Link href="/" className={styles.wordmark}>FindEZ</Link><span className={styles.topDivider} aria-hidden>/</span><Link href="/docs/api" className={styles.docsLabel}>Developers</Link></div>
      <Link href="/settings/api-keys" className={styles.manageLink}>Manage API keys<ArrowUpRight size={15} aria-hidden /></Link>
    </header>
    <div className={styles.layout}>
      <aside className={styles.sidebar}>
        <nav aria-label="API documentation contents">
          <p className={styles.navLabel}><BookOpen size={14} aria-hidden />Integration guide</p>
          {startingSections.map(section => <a key={section.id} href={`#${section.id}`}>{section.title}</a>)}
          <a href="#endpoints">Endpoint reference</a>
          <div className={styles.endpointNav}>{apiEndpoints.map(endpoint => <a key={endpoint.id} href={`#${endpoint.id}`}><span>{endpoint.method}</span><code>{endpoint.path}</code></a>)}</div>
          {remainingSections.map(section => <a key={section.id} href={`#${section.id}`}>{section.title}</a>)}
          <div className={styles.navFooter}><a href="/docs/api/openapi.json" download="findez-openapi.json"><ArrowDownToLine size={14} aria-hidden />OpenAPI specification</a><a href="mailto:info@findez.ai">Contact support<ArrowUpRight size={13} aria-hidden /></a></div>
        </nav>
      </aside>
      <main id="documentation-content" className={styles.content} tabIndex={-1}>
        <article>
          <header className={styles.hero}>
            <p className={styles.eyebrow}>FindEZ developer documentation<span>API v1</span></p>
            <h1>Build with your inventory.</h1>
            <p className={styles.lead}>A practical reference for connecting reports, automations, AI tools, and business systems to FindEZ Team inventory.</p>
            <div className={styles.meta}><span>Reviewed {DOCS_UPDATED}</span><span>HTTPS · JSON · Bearer authentication</span></div>
            <div className={styles.actions}>
              <Link href="/settings/api-keys" className={styles.primaryButton}><KeyRound size={15} aria-hidden />Create an API key</Link>
              <a href="/docs/api/guide.md" download="findez-api-guide.md" className={styles.textButton}><ArrowDownToLine size={15} aria-hidden />Download guide</a>
              <PrintDocumentation />
            </div>
            <div className={styles.baseUrl}><span>Production base URL</span><code>{API_BASE}</code></div>
          </header>
          {startingSections.map(section => <GuideSection key={section.id} section={section} />)}
          <section id="endpoints" className={styles.section} aria-labelledby="endpoints-title">
            <h2 id="endpoints-title">Endpoint reference<a href="#endpoints" aria-label="Link to Endpoint reference">#</a></h2>
            <p>Paths below are relative to the production base URL. Each example shows the required credential, a sample request, and a successful response. UUIDs and response values are illustrative.</p>
            <p>For complete machine-readable request and response models, <a href="/docs/api/openapi.json" download="findez-openapi.json">download the OpenAPI 3.1 specification</a>. Field constraints and server-side validation rules are also covered in <a href="#item-fields">Item fields</a> and <a href="#query-language">Query language</a>.</p>
            {apiEndpoints.map(endpoint => <section key={endpoint.id} id={endpoint.id} className={styles.endpoint} aria-labelledby={`${endpoint.id}-title`}>
              <div className={styles.endpointPath}><span className={styles.method}>{endpoint.method}</span><code>{endpoint.path}</code></div>
              <h3 id={`${endpoint.id}-title`}>{endpoint.title}<a href={`#${endpoint.id}`} aria-label={`Link to ${endpoint.title}`}>#</a></h3>
              <p>{endpoint.description}</p>
              <dl className={styles.endpointFacts}>
                <div><dt>Authentication</dt><dd>{endpoint.auth === "apiKey" ? "API key" : "FindEZ user access token — not an API key"}</dd></div>
                <div><dt>Permission</dt><dd>{endpoint.scopes.length ? endpoint.scopes.join(" or ") : endpoint.auth === "apiKey" ? "Any active key" : "Signed-in team owner"}</dd></div>
                <div><dt>Success</dt><dd>{endpoint.status} {endpoint.status === 201 ? "Created" : "OK"}</dd></div>
              </dl>
              {endpoint.parameters && <ul className={styles.parameters}>{endpoint.parameters.map(parameter => <li key={parameter.name}><code>{parameter.name}</code><span> · {parameter.in} · {parameter.required ? "required" : "optional"}</span><p>{parameter.description}</p></li>)}</ul>}
              <ul>{endpoint.notes.map(note => <li key={note}>{note}</li>)}</ul>
              <CodeExample label={`${endpoint.method} ${endpoint.path} request`} language="cURL" value={endpointCurl(endpoint)} />
              <CodeExample label={`${endpoint.method} ${endpoint.path} response`} language={`JSON · ${endpoint.status}`} value={JSON.stringify(endpoint.response, null, 2)} />
            </section>)}
          </section>
          {remainingSections.map(section => <GuideSection key={section.id} section={section} />)}
        </article>
        <footer className={styles.footer}><p>FindEZ Integration API · v1</p><div><a href="mailto:info@findez.ai">info@findez.ai</a><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link><a href="#documentation-content">Back to top ↑</a></div></footer>
      </main>
    </div>
  </div>;
}
