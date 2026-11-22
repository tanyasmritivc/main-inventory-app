import { cadWorldPath } from "@/lib/cad-links";
import Link from 'next/link';
import type { ReactNode } from 'react';
import { HeaderMarkup, FooterMarkup } from '@/components/marketing-dark/public-chrome';
import { AppThemeProvider } from './use-app-theme';
import { CodeExample, DocsAppearance } from './api-docs-controls';
import { CadDocsNavigation } from './cad-docs-navigation';
import styles from './api-docs.module.css';

function ReferenceTable({ caption, headings, rows }: { caption: string; headings: string[]; rows: ReactNode[][] }) {
  return <div className={styles.tableWrap}><table><caption>{caption}</caption><thead><tr>{headings.map(title => <th key={title} scope="col">{title}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={index}>{row.map((cell, column) => <td key={column}>{cell}</td>)}</tr>)}</tbody></table></div>;
}

export function CadDocs({ world }: { world?: string } = {}) {
  const comparisonHref = world ? `/cad?world=${encodeURIComponent(world)}` : '/cad';
  return <AppThemeProvider><div className={styles.siteHeader}><HeaderMarkup reserveSpace manageScroll={false} /></div><div className={styles.page}>
    <a href="#cad-docs-content" className={styles.skipLink}>Skip to documentation</a>
    <header className={styles.header}><Link href={cadWorldPath("/docs/cad", world)} className={styles.brand}>CAD Intelligence</Link><div><a href="#downloads">Downloads</a><Link href={comparisonHref}>Open comparison tool ↗</Link><DocsAppearance /></div></header>
    <div className={styles.layout}>
      <aside className={styles.sidebar}><CadDocsNavigation /></aside>
      <main id="cad-docs-content" className={styles.content}>
        <div className={styles.hero}><p className={styles.eyebrow}>CAD documentation</p><h1>Connect your design to your inventory.</h1><p>Your home for everything CAD: install FindEZ, create your first model, search parts, compare inventory, and review saved BOMs. Find downloads, tools, and help here.</p><div className={styles.baseUrl}><span>Fusion workspace</span><code>0.5.1 · Candidate</code><a href="/downloads/findez-fusion-workspace.zip?v=0.5.1" download>Download workspace ZIP ↓</a></div><p className={styles.muted}>Public documentation · Reviewed November 16, 2026 · Examples use fictional data</p></div>

        <section id="quickstart"><h2>Choose your workflow</h2>
          <ReferenceTable caption="CAD tools and guides" headings={['I want to…', 'Open']} rows={[
            ['Set up or update the Fusion add-in', <a key="setup" href="#downloads">Downloads and installation</a>],
            ['Make a model without knowing how to design in Fusion', <a key="first" href="#first-model">Create your first design</a>],
            ['Connect or manage Fusion access', <Link key="connect" href={cadWorldPath("/cad/fusion/connect", world)}>Connect an inventory / manage sessions</Link>],
            ['Compare a file or review saved BOM versions', <Link key="compare" href={comparisonHref}>Comparison and saved BOMs</Link>],
            ['Fix a problem', <a key="help" href="#troubleshooting">Troubleshooting</a>],
          ]} /><p>A bill of materials (BOM) lists the parts and quantities a design requires. FindEZ compares that list with one inventory you can access. Start with the workflow that fits your design.</p>
          <ReferenceTable caption="Available CAD workflows" headings={['Workflow', 'Use it for', 'Start here']} rows={[
            ['Fusion workspace candidate', 'Search parts with AI, generate custom STEP models, insert project models, compare the assembly, and save BOM versions inside Fusion.', <a key="fusion" href="#install">Install the workspace add-in</a>],
            ['Fusion export and web upload', 'Export component metadata to JSON and compare it in your browser. Both add-ins retain Export FindEZ BOM.', <a key="export" href="#export">Export a parts list</a>],
            ['Onshape CSV upload', 'Export a flattened BOM from Onshape, then review its columns in FindEZ.', <a key="onshape" href="#onshape">Use an Onshape BOM</a>],
            ['CSV or Excel upload', 'Compare an existing flat parts list from another CAD tool or spreadsheet.', <a key="sheet" href="#spreadsheet">Prepare your spreadsheet</a>],
          ]} />
          <p>You need a FindEZ account and access to the inventory you want to check. Documentation and downloads are public. The connection and comparison tools ask you to sign in and select an inventory. Checking a design does not reserve, consume, or add stock.</p>
        </section>

        <section id="downloads"><h2>Downloads & versions</h2><p>Download on the computer where Fusion runs. Extract the ZIP before adding it to Fusion. The workspace and export-only add-ins use the same FindEZ name; keep only the intended version registered and running.</p>
          <ReferenceTable caption="Choose the correct download" headings={['Download', 'Version', 'Includes']} rows={[
            [<a key="workspace" href="/downloads/findez-fusion-workspace.zip?v=0.5.1" download>Fusion workspace ZIP</a>, '0.5.1 candidate', 'Open FindEZ and Export FindEZ BOM. Windows and macOS. Use this for the connected panel.'],
            ['Legacy export-only add-in (superseded)', '0.1.0', 'Export FindEZ BOM only. Does not include Open FindEZ or a connected panel.'],
            [<a key="template" href="/downloads/findez-bom-template.csv" download>CSV template</a>, 'Flat BOM', 'Example columns for a spreadsheet comparison. Replace the sample rows with your own parts.'],
          ]} />
          <p><strong>Version 0.5.1:</strong> fixes unclear purchase-plan error messages. It retains optional purchasing inside Fusion, shared-stock planning, saved-version comparisons, and nominal specification checks. It keeps the slate-grey panel. It retains shared BOM versions, remembered match corrections, and RexCAD STEP generation. Enable model generation and saved BOMs for CAD writes; separately enable purchase plans and receiving for purchasing. Generation sends your submitted specifications to RexCAD and can ask clarification questions. STEP downloads are checked automatically before insertion. Check the inserted model and its placement before using it. Downloading a ZIP does not update an installed add-in.</p>
        </section>

        <section id="install"><h2>Install the Fusion workspace</h2><ol>
          <li>Download the <a href="/downloads/findez-fusion-workspace.zip?v=0.5.1" download>Fusion workspace ZIP</a>. On Windows, right-click it and choose <strong>Extract All</strong>. On macOS, double-click it.</li>
          <li>Open Fusion and switch to the <strong>Design</strong> workspace. Open <strong>Utilities → Add-Ins → Scripts and Add-Ins</strong>.</li>
          <li>If an older FindEZ entry exists, follow <a href="#update">Update an existing installation</a> first.</li>
          <li>Click <strong>+ → Script or Add-In from device</strong>. Select the inner <strong>FindEZ</strong> folder that directly contains <code>FindEZ.py</code> and <code>FindEZ.manifest</code>. Select the folder, not the ZIP or a Python file.</li>
          <li>Select FindEZ and confirm <strong>version 0.5.1</strong>. Turn on its <strong>Run</strong> toggle. Older Fusion versions use a Run button. Optionally enable Run on Startup.</li>
          <li>Close the dialog. Choose <strong>Utilities → Add-Ins → Open FindEZ</strong>. A FindEZ panel should open beside your design with a <strong>Sign in with FindEZ</strong> button.</li>
        </ol>
          <CodeExample label="Extracted workspace folder" examples={{ Folder: 'findez-fusion-workspace/\n  README.md\n  FindEZ/                 ← select this folder\n    FindEZ.py\n    FindEZ.manifest\n    workspace.py\n    client.py\n    placement.py\n    exporter.py\n    palette.html\n    palette.css\n    palette.js\n    planning.js\n    purchasing.js' }} />
          <p>The folder may have a suffix such as <code>(2)</code> after a repeat download. Check the files and version, rather than assuming a folder name identifies the build. Do not rename the inner FindEZ folder or its entry files.</p>
        </section>

        <section id="update"><h2>Update an existing installation</h2><ol>
          <li>In Scripts and Add-Ins, select FindEZ and switch <strong>Run</strong> off.</li>
          <li>Check the <strong>Full Path</strong> field. If it points to <code>findez-fusion-preview</code>, it is the export-only installation. Remove that old registration using the remove/unlink control.</li>
          <li>Close Fusion. Extract the new workspace ZIP. Replace the complete contents of your registered FindEZ folder, or register the new extracted inner FindEZ folder after reopening Fusion.</li>
          <li>Restart Fusion so its Python modules reload. Confirm the intended folder and <strong>0.5.1</strong> in the add-in manager, switch Run on, and open FindEZ.</li>
        </ol><p>Updating the add-in does not change your designs or inventory. Reconnect after restarting: the Fusion session is kept in memory. If you still see only Export FindEZ BOM, check the registered version and path before downloading again.</p></section>

        <section id="connect"><h2>Connect an inventory</h2><ol>
          <li>In the Fusion panel, click <strong>Sign in with FindEZ</strong>. Keep the displayed ten-character code visible.</li>
          <li>Your normal browser opens the <Link href={cadWorldPath("/cad/fusion/connect", world)}>Fusion connection page</Link>. Sign in to FindEZ there, choose Personal or your organization, and select an inventory you can access.</li>
          <li>Check that the code matches your Fusion panel. Select <strong>I started this connection in Fusion and the code matches</strong>.</li><li>To generate models or save BOMs, also select <strong>Enable model generation and saved BOMs</strong>. This separate, optional checkbox is available to inventory editors. Leaving it unchecked allows browsing and comparison only.</li><li>To manage purchases inside Fusion, separately select <strong>Enable purchase plans and receiving</strong> when available. This permits confirmed deliveries to increase stock. Owners/admins approve and record orders.</li><li>Click <strong>Connect this inventory</strong>.</li>
          <li>Return to Fusion. The panel connects automatically and shows the selected inventory. If the code expired, start sign-in again from the panel.</li>
        </ol><p>Pairing codes expire after ten minutes. A connected session lasts up to eight hours and is limited to the selected inventory. Use <strong>Disconnect</strong> to choose another inventory. Opening the connection page alone does not create a pairing code.</p>
          <h3>Review or revoke a connection</h3><p>Open <Link href={cadWorldPath("/cad/fusion/connect", world)}>Manage Fusion connections</Link>, select an inventory, and review <strong>Your active Fusion connections</strong>. Reload after a new connection completes. Disconnect an entry to revoke it. If Fusion cannot reach the server during disconnect, its local session is cleared, but server revocation must be retried from the browser or allowed to expire.</p>
        </section>

        <section id="first-model"><h2>Create your first design</h2><p>You do not need to draw the part yourself. Start with an empty, editable Fusion design; FindEZ can generate the geometry from your description.</p><ol>
          <li>In Fusion, choose <strong>File → New… → Hybrid Design → Create New</strong>. Save it as <strong>My First Model</strong> in a project. Use your own design, not a read-only sample.</li>
          <li>Open <strong>Utilities → Add-Ins → Open FindEZ</strong>. <a href="#connect">Connect an inventory</a> with model generation enabled. Generating a part does not add it to stock.</li>
          <li>In the <strong>Generate</strong> tab, enter the name <strong>Mounting plate</strong>, choose <strong>mm</strong>, and paste the specification below.</li>
        </ol><CodeExample label="Your first model specification" examples={{ Specification: 'Create a rectangular plate 60 mm long, 40 mm wide, and 5 mm thick. Add one 10 mm diameter hole through its center. Center the plate in XY with its bottom at Z=0. No rounded edges. Return one solid STEP.' }} /><ol start={4}>
          <li>Select the consent checkbox for sending this specification to RexCAD, then click <strong>Generate model</strong>. This consent is separate from the connection permission.</li>
          <li>Click <strong>Refresh status</strong> to check progress. Answer any clarification in the panel. A queued job has already been submitted; do not start another copy.</li>
          <li>When the status is <strong>succeeded</strong>, select the model-review acknowledgement and click <strong>Insert generated STEP</strong>. The download happens automatically.</li>
          <li>In <strong>Place FindEZ Component</strong>, leave distances and angles at zero for this example, then click <strong>OK</strong>. Cancel removes the inserted copy.</li>
          <li>Save your Fusion design. Use <strong>Inspect → Measure</strong> to check the plate is 60 × 40 × 5 mm and the hole diameter is 10 mm before relying on it.</li>
        </ol><p>Generated geometry is unverified until reviewed. A successful generation or checksum confirms delivery, not engineering suitability.</p></section>

        <section id="browse"><h2>Search inventory & catalog with AI</h2><p>Choose <strong>Inventory</strong> for owned stock or <strong>Catalog</strong> for public part records. AI search is the default: try “Find 12 M4 screws” or “Find bearings for an 8mm shaft.” Ask “Do I have the parts required to make this?” to read the open assembly and start its inventory comparison in the BOM tab. Part searches use saved names and specifications; they do not inspect the design. Results, locations, and quantities come from saved records. Missing specifications are marked unverified, and results require compatibility review. A catalog record is not owned inventory.</p><p>Use <strong>Keyword search</strong> for a literal part name, or if AI is unavailable. Inventory keyword search also checks recorded brand, part number and location. Location filters apply to inventory. AI shows up to 50 candidate matches; narrow the question if results are limited. Requested shortages are calculated separately for each inventory record, not by adding different candidate parts together. Use the <strong>BOM</strong> tab to compare the current assembly.</p>
          <ReferenceTable caption="Read quantities correctly" headings={['Quantity', 'Meaning']} rows={[
            ['On hand', 'Recorded inventory quantity. FindEZ does not physically count the shelf.'],
            ['Reserved', 'Units already committed through existing inventory reservations.'],
            ['Checked out', 'Units recorded as checked out and unavailable for this comparison.'],
            ['Available', 'Recorded quantity after reservations and active checkouts are deducted, with a floor of zero.'],
            ['Required', 'Units needed by the current assembly or uploaded parts list.'],
            ['Missing / to buy', 'Required units not covered by confirmed available matches. Review uncertain rows first.'],
          ]} /><p>Search results do not supply vendor quotes or on-order stock. Review manual quotes and recorded orders in Purchases, and incoming deliveries in multi-project planning. Inserting a part into a design does not reserve or consume it.</p>
        </section>

        <section id="insert"><h2>Insert a model without leaving Fusion</h2><p>Search for a part, then choose geometry from your active design or saved Fusion project. A local STEP download is not required for these models.</p><ol>
          <li>Open an editable Fusion design. On a part result, choose <strong>Choose Fusion model</strong>.</li>
          <li>Use <strong>Current design</strong> to copy an existing component, or <strong>Fusion project</strong> to browse folders and saved Fusion designs. Save the active design to a project first to use the project browser.</li>
          <li>Check that the geometry matches the selected part. Confirm that check and choose <strong>Insert into design</strong>.</li>
          <li>Position the new copy with the translation and rotation handles, then confirm. Cancel removes the copy. Existing model geometry and inventory stock stay unchanged.</li>
        </ol><p>The new component records the inventory or catalog identity and model source. Previously associated components appear first in the current-design picker. Save the Fusion design to retain these associations. Geometry remains unverified until you check its dimensions, units and compatibility.</p><p>If a part has no geometry in your Fusion project, it cannot yet be inserted automatically from the catalog. Manufacturer CAD downloads are not connected. To create a new custom part without leaving the panel, use the <a href="#generate">Generate tab</a>. You can create the geometry in Fusion, or use <strong>Other model sources → Import a local STEP or F3D file</strong> as an optional fallback. Review the imported geometry and placement before confirming.</p></section>

        <section id="bom"><h2>Compare inside Fusion</h2><ol>
          <li>Open the assembly and configuration you intend to build. Resolve missing references first.</li>
          <li>In the connected FindEZ panel, open <strong>BOM</strong> and click <strong>Compare current assembly</strong>.</li>
          <li>Review the summary, warnings, part identities, required quantities, and recorded coverage.</li>
          <li>Use <strong>Export shortages CSV</strong> to save uncovered requirements locally. Review needs-review rows before treating them as confirmed purchase requirements.</li>
        </ol><p>This is a snapshot. Compare again after changing the design or inventory. Hidden parts count; suppressed subtrees are excluded when the exporter can determine suppression. Unknown suppression or incomplete references can require review. Comparing does not save a persistent CAD project or change stock.</p></section>

        <section id="history"><h2>Save BOM versions and correct matches</h2><ol>
          <li>Save the design to your Fusion project. Reconnect FindEZ and enable the optional CAD writing permission. You need editing access to the selected inventory.</li>
          <li>Open BOM and compare the assembly. Use <strong>Correct this match</strong> to remember a reviewed match or mark that none of the candidates match. Compare again to see the updated allocation.</li>
          <li>Click <strong>Save BOM version</strong>. FindEZ reads the assembly and current inventory again, then stores an immutable version. Retrying a failed save does not create a duplicate.</li>
          <li>Open <strong>Saved BOM versions</strong> in the panel or the web comparison page. Saved counts are historical; compare again for current availability.</li>
        </ol><p>Versions and corrections are shared with authorized readers of this inventory. Saving does not reserve or consume stock. Up to 500 projects per inventory and 200 versions per project are supported.</p><p>In Fusion, load saved versions and expand <strong>Compare saved versions</strong>. Choose two versions of the same project. On the web, open a saved version and choose another version of the same project under <strong>Compare requirements with</strong>. The comparison shows added, removed, and changed quantities. Parts without a manufacturer and part number retain their definition identity and need review. Specification or catalog identity changes are kept separate when present. This comparison does not inspect geometry, refresh stock, or verify engineering compatibility.</p></section>

        <section id="planning"><h2>Plan several projects against shared stock</h2><ol><li>Load saved BOM versions. In Fusion, expand <strong>Plan several projects</strong> in BOM. On the web, expand <strong>Plan multiple projects</strong> below the saved history.</li><li>Select one saved version per project, up to twenty. The order you select them sets priority; use <strong>Move earlier</strong> to change it.</li><li>Choose <strong>Compare shared stock</strong>. Earlier projects receive available stock first. One unit cannot cover two projects. Existing reservations and checkouts are excluded, including reservations for the selected projects.</li><li>Review shortages and uncertain matches. On-order quantities are listed separately and never counted as physically available. This preview does not reserve or purchase parts.</li></ol><p>The preview uses saved design requirements and newly read inventory. It is not an atomic stock commitment; compare again after inventory changes.</p></section>
        <section id="purchasing"><h2>Plan purchases, compare quotes, and receive parts</h2>
          <p>This workflow is in the signed-in <Link href={comparisonHref}>CAD comparison and history tool</Link>, under <strong>Purchase plans</strong>, when purchasing is enabled on the server. In Fusion 0.5.1, reconnect and separately enable <strong>purchase plans and receiving</strong>, then open <strong>Purchases</strong>. This option appears only after the server enables native purchasing. Existing connections gain no new permissions. Supplier quotes are entered by your team; FindEZ has no live vendor feed connected.</p>
          <ol>
            <li>Save a BOM in Fusion. In Purchases, load saved BOMs, choose a version and click <strong>Create plan from current shortages</strong>. On the web, load and select that version, open Purchase plans, then choose <strong>Create plan from selected BOM</strong>. FindEZ compares the saved design with current inventory. Resolve incomplete extraction and ambiguous purchase lines first. Fabricated components are not added to the purchase list.</li>
            <li>For each shortage, add a supplier quote with its HTTPS product link, source or reference, currency, price per individual unit, pack size, minimum order, quote date, and expiry. Confirm the exact variant, dimensions, and material yourself.</li>
            <li>Add bulk price breaks as one quantity and unit price per line, for example <code>100, 0.08</code>. In Fusion, separate breaks with semicolons, for example <code>100, 0.08; 250, 0.06</code>. These are prices for every unit once that quantity is reached. FindEZ compares pack-rounded quantities and shows extra units if a larger order costs less.</li>
            <li>Select a quote for every line. Prices remain separate by currency and exclude shipping and tax. Expired and out-of-stock quotes cannot be selected or approved. Listed stock is supplier information, not a physical stock check.</li>
            <li>An inventory owner or administrator approves the selected quotes and quantities. Use <strong>Export by vendor</strong> to create a purchasing CSV. Place orders with the vendors yourself, then record all vendor order references. FindEZ does not perform checkout or payment.</li>
            <li>When a delivery arrives, choose <strong>Receive</strong>, search for the existing destination stock record, enter only the quantity delivered now, and confirm the part and location. Receiving increases that record&apos;s stock and records a restock event. Create a stock record in the inventory first if needed. Partial deliveries leave the remaining quantity on order.</li>
          </ol>
          <p>Creating, approving, or marking a plan ordered does not add stock. One active plan is allowed per CAD project. Plans are shared with authorized inventory readers; editors can prepare quotes and receive deliveries, while owners and administrators approve and record orders. Approved plans can be reopened before ordering. Draft and approved plans can be cancelled. Ordered plans must be received; vendor cancellations and returns are not supported here yet.</p>
          <p>If a connection fails while saving, use <strong>Retry the same change</strong>. The web page retains the pending request in this browser tab for this account and inventory, including across reloads. Fusion retains the request locally for the same account and inventory across reconnection; no credentials are stored. If local request storage fails, native purchasing pauses. Confirm the result before starting another delivery entry. Duplicate retries do not add stock twice. A saved plan&apos;s quantities are planning snapshots; check other project commitments and outstanding orders before purchasing.</p>
        </section>

        <section id="generate"><h2>Generate a STEP model inside Fusion</h2><ol>
          <li>Connect with CAD writing permission, then open the <strong>Generate</strong> tab. Enter a name, units, and explicit dimensions. Include holes, orientation, material-related constraints, and required geometry where relevant.</li>
          <li>Confirm that your specification will be sent to RexCAD and click <strong>Generate model</strong>. Existing assembly geometry and inventory records are not sent.</li>
          <li>Use <strong>Refresh status</strong>. If RexCAD asks for an essential dimension, answer it in the panel. Use <strong>My recent generation jobs</strong> to resume after reconnecting to the same inventory.</li>
          <li>When the job succeeds, acknowledge that you will check the model and click <strong>Insert generated STEP</strong>. FindEZ downloads the STEP automatically and verifies its size and checksum. Position it in the active design and confirm, or cancel to remove the inserted copy.</li>
          <li>Inspect dimensions and save your Fusion design. Provider results expire after seven days. Generated components are labeled unverified and treated as fabricated parts, not owned inventory or certified manufacturer parts.</li>
        </ol><p>Generation is limited to 20 new jobs per account per day, 16,000 specification characters, and 100 MiB STEP downloads. The provider key stays on the FindEZ server. Drawing uploads, generated previews, automatic catalog publication, and nightly generation are not included in this candidate.</p><CodeExample label="Example dimensional specification" examples={{ Specification: 'Create a 60 x 40 x 5 mm plate centered in XY, bottom Z=0, with a centered 10 mm diameter through hole. No fillets or chamfers. Return one solid STEP.' }} /><ReferenceTable caption="Generation status and next step" headings={['Status', 'What to do']} rows={[
          ['queued / running / validating', 'The request is accepted. Use Refresh status; do not submit the same model again.'],
          ['needs_input', 'Read the clarification question, answer in the panel, and refresh status afterward.'],
          ['succeeded', 'Acknowledge model review, insert the STEP, confirm placement, and save the design.'],
          ['failed / cancelled', 'Read the message. Correct the specification if needed before deliberately starting a new job.'],
          ['expired', 'Temporary provider results are no longer available. Use a copy saved in your Fusion design, or generate again.'],
        ]} /></section>

        <section id="export"><h2>Export a parts list from Fusion</h2><p>Use this workflow if you prefer browser comparison. Export FindEZ BOM is available in both the workspace candidate and the older export-only add-in. Exporting itself does not require a FindEZ connection.</p><ol>
          <li>Open the intended assembly and configuration in Fusion.</li>
          <li>Choose <strong>Utilities → Add-Ins → Export FindEZ BOM</strong>.</li>
          <li>Save <code>findez-bom.json</code>, then review any export warnings.</li>
          <li>Open the <Link href={comparisonHref}>web comparison tool</Link> and upload that JSON file.</li>
        </ol><p>The JSON contains component metadata and assembly requirements. Do not upload STEP, STL, F3D, or F3Z geometry to the web comparison tool. If Fusion is on another computer, transfer the JSON or open FindEZ in a browser on that computer.</p></section>

        <section id="compare"><h2>Compare on the web</h2><ol>
          <li>Open <Link href={comparisonHref}>CAD comparison</Link>, sign in, and select the intended inventory.</li>
          <li>Choose <strong>Autodesk Fusion</strong> for an exported JSON file or <strong>CSV or Excel</strong> for a flat parts list.</li>
          <li>Select your file. For spreadsheets, choose <strong>Review columns</strong>, select a worksheet, map fields, and confirm the flat-list quantities.</li>
          <li>Click <strong>Compare with inventory</strong>. Review results and match evidence before using <strong>Export shortages</strong>.</li>
        </ol><p>Choose another inventory from the tool when needed. Results reflect the selected inventory and your current access. This workflow does not create inventory items, reserve stock, place orders, or modify the CAD design.</p></section>

        <section id="onshape"><h2>Use an Onshape BOM</h2><p>Onshape works with a CSV upload. A direct one-button Onshape app is not available in this production release and is not published in Onshape&apos;s App Store.</p><ol>
          <li>Open the intended assembly and configuration in Onshape.</li>
          <li>Open its Bill of Materials panel and choose a flattened parts list. Include Name, Quantity, and Part number. Remove assembly total and subtotal rows.</li>
          <li>Export to CSV, then open <Link href={comparisonHref}>FindEZ comparison</Link> and choose <strong>CSV or Excel</strong>.</li>
          <li>Review columns. Map Name to Component name, Quantity to Required quantity, and Part number to Manufacturer part number. Map manufacturer and barcode only when present; leave description and material unmapped.</li>
          <li>Confirm total individual-unit quantities, compare, and review uncertain matches before exporting shortages.</li>
        </ol><p>Purchased subassemblies and excluded parts depend on your Onshape BOM settings. Check that the exported list represents the build you intend. See <a href="https://cad.onshape.com/help/Content/Assembly/bill_of_material.htm" target="_blank" rel="noreferrer">Onshape&apos;s BOM documentation</a> for its table and export controls.</p></section>

        <section id="spreadsheet"><h2>CSV & Excel column mapping</h2><p>Upload a flat list with one header row and positive whole-number quantities in individual units. Select one worksheet from an Excel workbook. Remove assembly totals, subtotals, and duplicate summary rows before confirming the list.</p>
          <ReferenceTable caption="Supported BOM fields" headings={['Field', 'Presence', 'What to provide']} rows={[
            ['Component name', 'Required', 'The part name, not the material or a general description.'],
            ['Required quantity', 'Required', 'Total individual units needed for the selected build.'],
            ['Manufacturer part number', 'Optional', 'An exact identifier. Preserve punctuation and leading zeros as text.'],
            ['Manufacturer', 'Optional', 'The manufacturer or brand associated with the identifier.'],
            ['Barcode', 'Optional', 'The exact barcode value, formatted as text.'],
            ['Unit', 'Optional', 'Individual-unit information. Do not assume packs, lengths, or weights will be converted.'],
          ]} />
          <CodeExample label="Sample data: flat BOM CSV" examples={{ CSV: 'Component name,Required quantity,Manufacturer part number,Manufacturer\nExample bearing,8,EX-608,Example Parts\nExample motor,4,EX-MOTOR,Example Parts' }} />
          <p><a href="/downloads/findez-bom-template.csv" download>Download the CSV template</a>. Replace its sample data. Custom headers can be mapped manually. Save formulas as plain values and convert legacy <code>.xls</code> files to <code>.xlsx</code>.</p>
        </section>

        <section id="results"><h2>Statuses & matching</h2><p>Read status together with match evidence and export warnings. Similar names alone do not establish an exact part identity.</p>
          <ReferenceTable caption="Comparison status reference" headings={['Status', 'Meaning', 'Next action']} rows={[
            ['Covered', 'An exact identity match has enough available recorded stock.', 'Verify the physical stock and intended part before building.'],
            ['Short', 'Some units are covered, but more are required.', 'Check the uncovered quantity and export shortages.'],
            ['Missing', 'No units are covered by exact inventory matches.', 'Check identifiers and the selected inventory before buying.'],
            ['Needs review', 'The identity or requirement is uncertain.', 'Review evidence, warnings, and source data before relying on quantities.'],
          ]} />
          <h3>Identity evidence</h3><p>Exact barcodes or part numbers provide stronger evidence than names. Manufacturer information helps resolve conflicting suppliers or identifiers. Name-only candidates need review. The comparison does not validate mechanical fit, electrical ratings, materials, or engineering compatibility.</p>
          <h3>Quantities and corrections</h3><p>Existing reservations and checkouts reduce available recorded stock. Requirements competing for the same stock cannot each count all of it. Review the assigned and missing quantities per line. Editors with CAD writing permission can choose Correct this match, select a candidate, and remember the decision for this inventory. None match keeps the line unresolved; Forget correction removes the decision. The next comparison applies saved decisions only while both identities still match. These decisions do not certify engineering compatibility.</p>
          <p>Shortages exports are planning files, not purchase orders. Review needs-review rows, duplicate parts, and missing identifiers before ordering. Supplier quotes can be recorded separately in <a href="#purchasing">Purchase plans</a>; no automatic substitutions are made.</p>
        </section>

        <section id="limits"><h2>File limits & current limitations</h2>
          <ReferenceTable caption="Input limits" headings={['Input', 'Limit', 'Notes']} rows={[
            ['Web BOM upload', '5 MiB per file', 'Fusion JSON, CSV, or Excel .xlsx.'],
            ['Spreadsheet', '5,000 data rows, 200 columns, 20 worksheets', 'Only the selected worksheet is compared. Use plain values and individual units.'],
            ['Fusion JSON', '5,000 definitions and 20,000 occurrences', 'Use the add-in export schema; arbitrary JSON is not a BOM.'],
            ['Local model insertion', '100 MiB per file', 'STEP/STP or F3D, used locally inside Fusion. Not a web BOM upload.'],
          ]} /><p>Configuration, suppressed parts, missing references, and assembly structure can affect completeness. Quantities are snapshots, not a reservation or a physical stock check. The candidate does not provide hosted CAD assets, verified model previews, live pricing, automatic design changes, or automatic project synchronization. Saved BOM versions are explicit snapshots.</p></section>

        <section id="privacy"><h2>Privacy & permissions</h2><p>The Fusion panel loads its UI locally. Signing in opens your normal browser; do not enter your FindEZ password into a palette or share a pairing code you did not initiate.</p>
          <ReferenceTable caption="What leaves your computer" headings={['Action', 'Data used by FindEZ']} rows={[
            ['Export FindEZ BOM', 'Writes component metadata to a local JSON file. Export alone does not upload it.'],
            ['Compare current assembly / compare JSON', 'Sends component metadata and requirements to compare with the selected inventory. Assembly geometry is not uploaded.'],
            ['Review spreadsheet columns', 'Uploads the spreadsheet to read its headers and sample rows. Comparison reads the mapped list.'],
            ['AI parts search', 'Sends your search question to the configured AI service for interpretation. Inventory rows are retrieved separately with your connection permissions; they are not sent to that model.'],
            ['Choose Fusion model', 'Browses current-design components or saved designs in the active Fusion project. Copies selected geometry inside Fusion; it does not upload geometry to FindEZ or change stock.'],
            ['Save BOM version / correction', 'Stores component metadata, historical comparison or your reviewed match in the selected inventory. No assembly geometry is uploaded.'],
            ['Generate model', 'Sends the specification and clarification answers you explicitly submit to RexCAD. The generated STEP is downloaded through FindEZ into Fusion. Temporary provider results expire after seven days.'],
            ['Insert local model', 'Imports a local geometry file into Fusion. The file contents are not uploaded by this action.'],
          ]} /><p>Fusion sessions are scoped to one authorized inventory and held in memory. They are read-only by default. Inventory editors can explicitly permit shared BOM versions, match corrections, and model generation during pairing. CAD writing permission does not allow stock changes or purchases. The separate purchasing permission permits explicit receiving into inventory; existing sessions do not gain it automatically. The backend stores hashed credentials and checks current inventory permissions. The panel receives no bearer token. Restarting Fusion requires reconnecting; explicit server revocation is available on the connection page.</p><p>CAD uses FindEZ sign-in and its own scoped connection. Integration API keys do not authorize CAD routes. For external inventory scripts, use the separate <Link href="/docs/api">API documentation</Link>. See the <Link href="/privacy">Privacy Policy</Link> for the service&apos;s broader data practices.</p></section>

        <section id="sample"><h2>Try a sample design</h2><p>Open an assembly from Fusion&apos;s Data Panel under <strong>Samples → Basic Training → 06 - Assemblies</strong>. Compare it in the connected panel or export its BOM and upload the JSON. A blank Untitled design has no parts to compare.</p><p>Samples test the workflow; their parts may not exist in your inventory and may lack exact identifiers. Missing and needs-review results can be expected. Use an editable saved copy before inserting a model. No sample inventory is created automatically.</p></section>

        <section id="troubleshooting"><h2>Errors & troubleshooting</h2>
          <details><summary>Generate model is disabled or I cannot click it</summary><p>Check that you are connected, have an editable design open, and have completed the name, units, specification, and generation-consent fields. If the panel says to approve CAD writing access, disconnect and sign in again. On the browser connection page, select both the matching-code confirmation and the separate optional model-generation permission before connecting. Only an inventory editor can enable it. Selecting RexCAD consent inside Fusion alone does not grant this permission.</p></details>
          <details><summary>My model says queued — should I start again?</summary><p>No. The job has been accepted. Click Refresh status and answer any clarification that appears. My recent generation jobs lets you resume the same job after reconnecting to the same inventory.</p></details>
          <details><summary>I see the model and a Place FindEZ Component dialog</summary><p>Adjust its position if needed and click OK to keep it, or Cancel to remove the copy. Save the Fusion design and check dimensions. Seeing the shape does not verify every dimension or manufacturing requirement.</p></details>
          <details className={styles.responseFields}><summary>Creating a purchase plan fails or says the plan changed</summary><p>Version 0.5.0 used one generic conflict message for several different situations. Update to 0.5.1 to see the specific reason. A fully covered BOM, or one containing only fabricated/generated parts, has no purchase shortages. If rows need review, open BOM, compare the assembly, resolve them, save a new version, and select that version in Purchases. If a plan already exists, choose Load purchase plans and open it. These checks prevent duplicate or unconfirmed purchases.</p></details>
          <details className={styles.responseFields}><summary>I only see Export FindEZ BOM, not Open FindEZ</summary><p>Check Scripts and Add-Ins. Version 0.1.0 is export-only. Install the workspace ZIP, confirm version 0.5.1 and its Full Path, and switch Run on. Remove the old registration and restart Fusion after replacing files. Look under Design → Utilities → Add-Ins.</p></details>
          <details className={styles.responseFields}><summary>Sign-in shows Unsupported panel command</summary><p>Update to workspace version 0.5.1. Earlier versions could mistake Fusion’s acknowledgement messages for new commands and repeatedly display this error. Stop FindEZ, replace the complete extracted files, restart Fusion, confirm 0.5.1 in Scripts and Add-Ins, and try Sign in with FindEZ again.</p></details>
          <details className={styles.responseFields}><summary>Sign-in says FindEZ could not be reached</summary><p>Update the complete add-in to 0.5.1 and restart Fusion. This version includes public certificate roots for embedded Python and shows a specific error code if the connection still fails. TLS-CERT means certificate verification failed; check the computer date and managed-network HTTPS inspection. DNS means the API hostname could not be resolved. TIMEOUT or NETWORK means Fusion could not connect. Send the displayed code to support. The browser opening findez.ai does not by itself confirm Fusion can reach the API.</p></details>
          <details className={styles.responseFields}><summary>Open FindEZ says the site cannot be reached</summary><p>The initial panel should load locally, before sign-in. Version 0.5.1 retains the Windows file-URL fix. Stop FindEZ, replace the complete extracted files, restart Fusion, and confirm 0.5.1. Check that palette.html, palette.js, and palette.css are present beside FindEZ.py. If the error appears instead in your browser after clicking Sign in with FindEZ, check your internet connection and open the connection page directly.</p></details>
          <details className={styles.responseFields}><summary>Fusion says Failed to add script</summary><p>Extract the ZIP and select the inner FindEZ folder. FindEZ.py and FindEZ.manifest must sit directly inside it with those exact names. Do not select the outer download folder or a single file. Send support the exact error and folder picker screenshot if it still fails.</p></details>
          <details className={styles.responseFields}><summary>I cannot find Run, or neither command appears</summary><p>New Fusion versions use a small Run toggle in the FindEZ row; older versions have a Run button. Switch to the Design workspace, enable FindEZ, and close the manager. If it switches off or displays an error, capture that message. Searching with S cannot find a command that has not loaded.</p></details>
          <details className={styles.responseFields}><summary>The pairing code expired or the panel is not connected</summary><p>Start Sign in with FindEZ again inside Fusion. Use the new code within ten minutes and approve the same selected inventory. Confirm the code matches your panel. Return to Fusion; if the session has expired or access changed, disconnect and reconnect.</p></details>
          <details className={styles.responseFields}><summary>The inventory is empty or an expected part is missing</summary><p>Check the selected inventory and location filter, your current permissions, and the item identifiers. A catalog record is not inventory stock. Similar names do not confirm an identity. Reserved and checked-out units are not available for this comparison.</p></details>
          <details className={styles.responseFields}><summary>Compare with inventory is disabled</summary><p>Choose a supported file. For CSV or Excel, also review columns, select the worksheet, map name and quantity, and confirm that it is a flat individual-unit list.</p></details>
          <details className={styles.responseFields}><summary>The export has no parts or incomplete counts</summary><p>Open an assembly, select the intended configuration, and resolve external references. Hidden components still count; suppressed subtrees are excluded when identifiable. Review warnings and compare the requirements with your source BOM.</p></details>
          <details className={styles.responseFields}><summary>A local model fails to insert or has the wrong size</summary><p>Use an editable design and a supported STEP/STP or F3D file within the size limit. Cancel if units, dimensions, or orientation are wrong. Models remain unverified and are not automatically converted into certified manufacturer assets. Report the file format and error; do not send a private design by default.</p></details>
        </section>

        <section id="roadmap"><h2>Planned capabilities</h2><p>The current release is a Fusion workspace candidate with saved BOMs and on-demand generation. The following capabilities are planned, not available controls or promises of a release date.</p>
          <ReferenceTable caption="CAD development scope" headings={['Area', 'Planned work']} rows={[
            ['Fusion workspace', 'Complete native placement acceptance, hosted model retrieval and previews, and saved/frequently used parts.'],
            ['BOM and identity', 'A complete canonical variant catalog, automatic synchronization, and geometry-aware design-change analysis. Saved requirement comparisons and nominal specification conflict checks are supported; missing dimensions still need review.'],
            ['Parts and CAD assets', 'A curated manufacturer catalog with exact variants, source rights, model quality labels, validation, and incremental generation jobs.'],
            ['Pricing', 'Approved live vendor feeds and reviewed engineering alternatives. Team-supplied quote history and pack/bulk estimates are supported in web and separately authorized Fusion purchase plans when enabled.'],
            ['Procurement', 'Order cancellation/returns, automatic replenishment allocation, and vendor checkout. Web and separately authorized Fusion purchase plans support approval, order recording, and partial receiving when enabled.'],
            ['Further integrations', 'Direct Onshape connection and engineering-reviewed alternatives. Shared-stock planning previews support selected saved projects; they do not reserve stock.'],
          ]} /><p>Catalog availability, owned stock, CAD geometry, and vendor offers remain distinct. A generated model or similarly named part must not silently become a verified engineering substitute. Suggested purchases and design substitutions require human review.</p></section>

        <section id="support"><h2>Support & documentation coverage</h2><p>This guide covers the public CAD downloads, Fusion workspace candidate, export-only workflow, web comparison, Onshape CSV, and current limitations. The <Link href="/cad-intelligence">public CAD Intelligence page</Link> introduces the feature; the <Link href={comparisonHref}>comparison tool</Link> uses your signed-in inventory.</p><p>Contact <a href="mailto:info@findez.ai?subject=FindEZ%20CAD%20setup%20help">info@findez.ai</a> with your operating system, Fusion version, FindEZ add-in version, the step you reached, and the exact error or a redacted screenshot. Never include passwords, access tokens, pairing codes, or private design files.</p><div className={styles.footerLinks}><a href="#downloads">Downloads ↓</a><Link href={cadWorldPath("/cad/fusion/connect", world)}>Manage Fusion connections ↗</Link><Link href={comparisonHref}>Open comparison tool ↗</Link><Link href="/docs/api">API documentation</Link><a href="#quickstart">Back to start ↑</a></div></section>
      </main>
    </div>
  </div><FooterMarkup /></AppThemeProvider>;
}
