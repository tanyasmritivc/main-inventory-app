import { cadWorldPath } from "@/lib/cad-links";
import Link from 'next/link';
import { HeaderMarkup, FooterMarkup } from '@/components/marketing-dark/public-chrome';
import { connectionsPath } from '@/lib/commerce';
import { AppThemeProvider } from './use-app-theme';
import { DocsAppearance } from './api-docs-controls';
import { ConnectionsDocsNavigation } from './connections-docs-navigation';
import styles from './api-docs.module.css';

export function ConnectionsDocs({ organization }: { organization?: string } = {}) {
  const manageHref = connectionsPath(organization);
  return <AppThemeProvider>
    <div className={styles.siteHeader}><HeaderMarkup reserveSpace manageScroll={false} /></div>
    <div className={styles.page}>
      <a href="#connections-docs-content" className={styles.skipLink}>Skip to documentation</a>
      <header className={styles.header}>
        <Link href={organization ? `/docs/connections?organization=${encodeURIComponent(organization)}` : "/docs/connections"} className={styles.brand}>Connections</Link>
        <div><Link href={manageHref}>Manage connections ↗</Link><DocsAppearance /></div>
      </header>
      <div className={styles.layout}>
        <aside className={styles.sidebar}><ConnectionsDocsNavigation /></aside>
        <main id="connections-docs-content" className={styles.content}>
          <div className={styles.hero}>
            <p className={styles.eyebrow}>Connections documentation</p>
            <h1>Keep your purchases in context.</h1>
            <p>Import order history, find past purchases, and check before buying again. Learn how records belong to your personal account or organization, and how they relate to physical inventory.</p>
            <p className={styles.muted}>Public guide · Sign in to manage connections</p>
          </div>

          <section id="quickstart"><h2>Start with your purchase history</h2>
            <ol>
              <li>Open <Link href={manageHref}>Manage connections</Link> and choose the connection owner.</li>
              <li>Download your Amazon order-history export and select its CSV or ZIP file.</li>
              <li>Preview the records, check the destination, then select <strong>Save purchase history</strong>.</li>
              <li>Browse your purchase library or use <strong>Check before buying</strong> to look up a product.</li>
            </ol>
            <p>No inventory needs to be selected to import orders. An order records a purchase; it does not confirm that you still own the item or how many units are available.</p>
          </section>

          <section id="ownership"><h2>Choose who owns the records</h2>
            <div className={styles.tableWrap}><table><caption>Connection ownership</caption><thead><tr><th scope="col">Owner</th><th scope="col">Use for</th><th scope="col">Access</th></tr></thead><tbody>
              <tr><td>Personal</td><td>Your own purchase history.</td><td>Private to you, including when you belong to an organization.</td></tr>
              <tr><td>Organization</td><td>Purchases intended for that organization.</td><td>Managed by its owners and administrators.</td></tr>
            </tbody></table></div>
            <p>Use the <strong>Connection owner</strong> selector before importing or browsing. Changing this selector does not move personal records, share an existing import, or change your inventory.</p>
          </section>

          <section id="amazon"><h2>Import Amazon order history</h2>
            <ol>
              <li>In Manage connections, find <strong>Your Amazon order history</strong> and open the Amazon data-request link.</li>
              <li>Request order data and complete Amazon’s confirmation. Download the export when Amazon makes it available.</li>
              <li>Choose the downloaded ZIP or its <strong>Order History.csv</strong> file. Some exports name it <strong>Retail.OrderHistory.csv</strong>.</li>
              <li>Select <strong>Preview order history</strong>.</li>
            </ol>
            <p>If Safari extracted the download into a folder, open <strong>Your Orders → Your Amazon Orders</strong> and select the CSV inside. Select a file, not the folder.</p>
            <p>This is a file import, not continuous synchronization with your Amazon account. The history covers the orders included in the export.</p>
          </section>

          <section id="review"><h2>Review before saving</h2>
            <p>Check the owner, product names, dates, quantities, and order statuses in the preview. Select <strong>Save purchase history</strong> only when the destination and records are correct.</p>
            <p>The export needs Order ID, Product Name or Title, Quantity or Original Quantity, and Order Date. Dates and quantities must be valid. If an import fails, correct the reported issue and preview it again.</p>
            <p>Matching order items update when you import a newer export instead of being added twice. Review new exports before saving, especially if you edited the source file.</p>
          </section>

          <section id="library"><h2>Browse your purchase library</h2>
            <p>Use the purchase library to search saved products and review their order history. Under <strong>Your connections</strong>, select <strong>View records</strong> to inspect an import.</p>
            <p>Filter by status to inspect active, purchased, shipped, delivered, cancelled, returned, or unknown records. Cancelled and returned purchases are excluded from the library’s ordered-unit totals. These totals describe recorded purchases, not current stock.</p>
          </section>

          <section id="before-buying"><h2>Check before buying again</h2>
            <p>In <strong>Do you already have it?</strong>, enter a product name, ASIN, or full Amazon product link, then select <strong>Check before buying</strong>.</p>
            <p>Review the saved purchase and inventory evidence. Confirm the exact model or variant and what you still own before ordering. A similar name or a past order is not proof that the product is currently available.</p>
          </section>

          <section id="inventory"><h2>Keep physical inventory accurate</h2>
            <p>Purchase imports do not automatically create or update inventory items. Store stock, order history, and your physically verified inventory remain separate.</p>
            <ol>
              <li>Open <Link href="/inventory">your inventory</Link> and choose the correct inventory and Space.</li>
              <li>Check for an existing item. Update its quantity if it is already recorded.</li>
              <li>For a new item, use <strong>Add items → Manual</strong>. Choose its Space under <strong>Save to</strong>, enter its name, category, and the quantity you have now, then save.</li>
            </ol>
            <p>Use the quantity you have verified, accounting for returns, consumption, and items you no longer own.</p>
          </section>

          <section id="manage"><h2>Update or remove an import</h2>
            <p>Upload a newer export to update matching purchase records. Use <strong>Refresh</strong> in the management page to reload its connection list.</p>
            <p><strong>Delete imported records</strong> removes the selected import’s records from FindEZ. It does not delete orders at Amazon or physical inventory items. Check the selected owner and import before confirming removal.</p>
          </section>

          <section id="limits"><h2>Supported connections & limits</h2>
            <div className={styles.tableWrap}><table><caption>Amazon order-history imports</caption><thead><tr><th scope="col">Input</th><th scope="col">Limit or behavior</th></tr></thead><tbody>
              <tr><td>File format</td><td>Amazon order-history CSV or ZIP containing the export.</td></tr>
              <tr><td>File size</td><td>Up to 10 MB.</td></tr>
              <tr><td>Order rows</td><td>Up to 10,000 per import.</td></tr>
              <tr><td>Updates</td><td>Upload a newer export; file imports do not sync automatically.</td></tr>
            </tbody></table></div>
            <p>Personal Amazon order imports are separate from Shopify and Amazon seller integrations. Merchant setup is not currently exposed in this page. Other connection options depend on availability and account configuration; this guide does not imply they are enabled for your account.</p>
          </section>

          <section id="privacy"><h2>Data & privacy</h2>
            <p>Only purchase fields are saved from the order-history export. Addresses and payment details are discarded, and the uploaded file is not retained.</p>
            <p>Choose the intended owner before saving. Personal imports stay private; organization imports belong to the selected organization. You do not need to provide your Amazon password to FindEZ for a file import.</p>
            <p>See the <Link href="/privacy">Privacy Policy</Link> for broader service practices.</p>
          </section>

          <section id="troubleshooting"><h2>Troubleshooting</h2>
            <details className={styles.responseFields}><summary>I cannot select the downloaded folder</summary><p>Open the extracted folder and choose Order History.csv or Retail.OrderHistory.csv. Alternatively, select the original ZIP within the size limit.</p></details>
            <details className={styles.responseFields}><summary>The file is too large or cannot be read</summary><p>Use the order-history CSV rather than an archive containing unrelated data. Check the 10 MB and 10,000-row limits, required fields, dates, and quantities. Read the displayed error before retrying.</p></details>
            <details className={styles.responseFields}><summary>My organization is missing or access is denied</summary><p>Confirm you are signed in to the correct account and are an owner or administrator of that organization. Retry loading organizations if an error is shown. Switching to Personal does not transfer organization records.</p></details>
            <details className={styles.responseFields}><summary>An imported purchase does not appear in inventory</summary><p>This is expected. Imports populate purchase history. Verify what you have and add or update the physical inventory item separately.</p></details>
            <details className={styles.responseFields}><summary>Records are missing or out of date</summary><p>Check the connection owner, selected import, and active filters. Confirm the export contains the expected orders, then preview and save a newer export if needed. An empty result is not evidence that you never purchased the item.</p></details>
            <details className={styles.responseFields}><summary>The page reports a loading or save error</summary><p>Retry the failed action after checking your connection and sign-in. A failed load does not mean the library is empty. If the error continues, contact support with the action and displayed message.</p></details>
          </section>

          <section id="support"><h2>Related guides & support</h2>
            <p>Use the <Link href="/docs/api">API documentation</Link> for external inventory integrations and the <Link href={cadWorldPath("/docs/cad", organization)}>CAD documentation</Link> for design and bill-of-materials workflows.</p>
            <p>For help, email <a href="mailto:info@findez.ai?subject=FindEZ%20Connections%20help">info@findez.ai</a> with the step you reached and the displayed error. Redact private purchase details from screenshots and never include passwords or access tokens.</p>
            <div className={styles.footerLinks}><Link href={manageHref}>Manage connections ↗</Link><Link href="/docs/api">API documentation</Link><Link href={cadWorldPath("/docs/cad", organization)}>CAD documentation</Link><a href="#quickstart">Back to start ↑</a></div>
          </section>
        </main>
      </div>
    </div>
    <FooterMarkup />
  </AppThemeProvider>;
}
