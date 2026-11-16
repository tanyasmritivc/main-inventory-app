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
    <header className={styles.header}><Link href="/docs/cad" className={styles.brand}>CAD Intelligence</Link><div><a href="#downloads">Downloads</a><Link href={comparisonHref}>Open comparison tool ↗</Link><DocsAppearance /></div></header>
    <div className={styles.layout}>
      <aside className={styles.sidebar}><CadDocsNavigation /></aside>
      <main id="cad-docs-content" className={styles.content}>
        <div className={styles.hero}><p className={styles.eyebrow}>CAD documentation</p><h1>Connect your design to your inventory.</h1><p>Set up FindEZ in Fusion, compare a bill of materials with your recorded stock, and export what still needs attention. Find every download, workflow, limit, and troubleshooting step here.</p><div className={styles.baseUrl}><span>Fusion workspace</span><code>0.2.2 · Candidate</code><a href="/downloads/findez-fusion-workspace.zip?v=0.2.2" download>Download workspace ZIP ↓</a></div><p className={styles.muted}>Public documentation · Reviewed November 15, 2026 · Examples use fictional data</p></div>

        <section id="quickstart"><h2>Choose your workflow</h2><p>A bill of materials (BOM) lists the parts and quantities a design requires. FindEZ compares that list with one inventory you can access. Start with the workflow that fits your design.</p>
          <ReferenceTable caption="Available CAD workflows" headings={['Workflow', 'Use it for', 'Start here']} rows={[
            ['Fusion workspace candidate', 'Browse inventory and catalog records, insert a local model, and compare the open assembly inside Fusion. Native host acceptance is still in progress.', <a key="fusion" href="#install">Install the workspace add-in</a>],
            ['Fusion export and web upload', 'Export component metadata to JSON and compare it in your browser. Both add-ins retain Export FindEZ BOM.', <a key="export" href="#export">Export a parts list</a>],
            ['Onshape CSV upload', 'Export a flattened BOM from Onshape, then review its columns in FindEZ.', <a key="onshape" href="#onshape">Use an Onshape BOM</a>],
            ['CSV or Excel upload', 'Compare an existing flat parts list from another CAD tool or spreadsheet.', <a key="sheet" href="#spreadsheet">Prepare your spreadsheet</a>],
          ]} />
          <p>You need a FindEZ account and access to the inventory you want to check. Documentation and downloads are public. The connection and comparison tools ask you to sign in and select an inventory. Checking a design does not reserve, consume, or add stock.</p>
        </section>

        <section id="downloads"><h2>Downloads & versions</h2><p>Download on the computer where Fusion runs. Extract the ZIP before adding it to Fusion. The workspace and export-only add-ins use the same FindEZ name; keep only the intended version registered and running.</p>
          <ReferenceTable caption="Choose the correct download" headings={['Download', 'Version', 'Includes']} rows={[
            [<a key="workspace" href="/downloads/findez-fusion-workspace.zip?v=0.2.2" download>Fusion workspace ZIP</a>, '0.2.2 candidate', 'Open FindEZ and Export FindEZ BOM. Windows and macOS. Use this for the connected panel.'],
            ['Legacy export-only add-in (superseded)', '0.1.0', 'Export FindEZ BOM only. Does not include Open FindEZ or a connected panel.'],
            [<a key="template" href="/downloads/findez-bom-template.csv" download>CSV template</a>, 'Flat BOM', 'Example columns for a spreadsheet comparison. Replace the sample rows with your own parts.'],
          ]} />
          <p><strong>Version 0.2.2:</strong> fixes a panel acknowledgement loop that could display “Unsupported panel command” during sign-in. It also includes the Windows file-URL fix. The download has passed automated checks; native Fusion testing remains in progress. Downloading a newer ZIP does not update an already installed add-in.</p>
        </section>

        <section id="install"><h2>Install the Fusion workspace</h2><ol>
          <li>Download the <a href="/downloads/findez-fusion-workspace.zip?v=0.2.2" download>Fusion workspace ZIP</a>. On Windows, right-click it and choose <strong>Extract All</strong>. On macOS, double-click it.</li>
          <li>Open Fusion and switch to the <strong>Design</strong> workspace. Open <strong>Utilities → Add-Ins → Scripts and Add-Ins</strong>.</li>
          <li>If an older FindEZ entry exists, follow <a href="#update">Update an existing installation</a> first.</li>
          <li>Click <strong>+ → Script or Add-In from device</strong>. Select the inner <strong>FindEZ</strong> folder that directly contains <code>FindEZ.py</code> and <code>FindEZ.manifest</code>. Select the folder, not the ZIP or a Python file.</li>
          <li>Select FindEZ and confirm <strong>version 0.2.2</strong>. Turn on its <strong>Run</strong> toggle. Older Fusion versions use a Run button. Optionally enable Run on Startup.</li>
          <li>Close the dialog. Choose <strong>Utilities → Add-Ins → Open FindEZ</strong>. A FindEZ panel should open beside your design with a <strong>Sign in with FindEZ</strong> button.</li>
        </ol>
          <CodeExample label="Extracted workspace folder" examples={{ Folder: 'findez-fusion-workspace/\n  README.md\n  FindEZ/                 ← select this folder\n    FindEZ.py\n    FindEZ.manifest\n    workspace.py\n    client.py\n    placement.py\n    exporter.py\n    palette.html\n    palette.css\n    palette.js' }} />
          <p>The folder may have a suffix such as <code>(2)</code> after a repeat download. Check the files and version, rather than assuming a folder name identifies the build. Do not rename the inner FindEZ folder or its entry files.</p>
        </section>

        <section id="update"><h2>Update an existing installation</h2><ol>
          <li>In Scripts and Add-Ins, select FindEZ and switch <strong>Run</strong> off.</li>
          <li>Check the <strong>Full Path</strong> field. If it points to <code>findez-fusion-preview</code>, it is the export-only installation. Remove that old registration using the remove/unlink control.</li>
          <li>Close Fusion. Extract the new workspace ZIP. Replace the complete contents of your registered FindEZ folder, or register the new extracted inner FindEZ folder after reopening Fusion.</li>
          <li>Restart Fusion so its Python modules reload. Confirm the intended folder and <strong>0.2.2</strong> in the add-in manager, switch Run on, and open FindEZ.</li>
        </ol><p>Updating the add-in does not change your designs or inventory. Reconnect after restarting: the Fusion session is kept in memory. If you still see only Export FindEZ BOM, check the registered version and path before downloading again.</p></section>

        <section id="connect"><h2>Connect an inventory</h2><ol>
          <li>In the Fusion panel, click <strong>Sign in with FindEZ</strong>. Keep the displayed ten-character code visible.</li>
          <li>Your normal browser opens the <Link href="/cad/fusion/connect">Fusion connection page</Link>. Sign in to FindEZ there, choose Personal or your organization, and select an inventory you can access.</li>
          <li>Check that the code on the page matches your Fusion panel. Confirm that you started the connection, then click <strong>Connect this inventory</strong>.</li>
          <li>Return to Fusion. The panel connects automatically and shows the selected inventory. If the code expired, start sign-in again from the panel.</li>
        </ol><p>Pairing codes expire after ten minutes. A connected session lasts up to eight hours and is limited to the selected inventory. Use <strong>Disconnect</strong> to choose another inventory. Opening the connection page alone does not create a pairing code.</p>
          <h3>Review or revoke a connection</h3><p>Open <Link href="/cad/fusion/connect">Manage Fusion connections</Link>, select an inventory, and review <strong>Your active Fusion connections</strong>. Reload after a new connection completes. Disconnect an entry to revoke it. If Fusion cannot reach the server during disconnect, its local session is cleared, but server revocation must be retried from the browser or allowed to expire.</p>
        </section>

        <section id="browse"><h2>Browse inventory & catalog records</h2><p>Use <strong>Inventory</strong> to search the selected inventory by name, part number, or location. Filter by location and use the page controls to browse results. Use <strong>Parts catalog</strong> for catalog records. A catalog entry is not a claim that your team owns the part, and it does not guarantee that a model or price is available.</p>
          <ReferenceTable caption="Read quantities correctly" headings={['Quantity', 'Meaning']} rows={[
            ['On hand', 'Recorded inventory quantity. FindEZ does not physically count the shelf.'],
            ['Reserved', 'Units already committed through existing inventory reservations.'],
            ['Checked out', 'Units recorded as checked out and unavailable for this comparison.'],
            ['Available', 'Recorded quantity after reservations and active checkouts are deducted, with a floor of zero.'],
            ['Required', 'Units needed by the current assembly or uploaded parts list.'],
            ['Missing / to buy', 'Required units not covered by confirmed available matches. Review uncertain rows first.'],
          ]} /><p>On-order quantities, vendor availability, and prices are not supplied by this candidate. Inserting a part into a design does not reserve or consume it.</p>
        </section>

        <section id="insert"><h2>Insert a local model</h2><p>The workspace candidate can insert a model file you already have. It does not yet download verified manufacturer models from a hosted CAD library.</p><ol>
          <li>Open an editable Fusion design. Select an inventory or catalog record in FindEZ and choose <strong>Insert local model</strong>.</li>
          <li>Choose a local STEP (<code>.step</code> or <code>.stp</code>) or Fusion archive (<code>.f3d</code>) up to 100 MiB.</li>
          <li>Position the imported component with the translation and rotation handles, then confirm. Scaling is disabled. Cancel removes the new occurrence.</li>
          <li>Check dimensions, units, orientation, and the association with the selected part before using it.</li>
        </ol><p>The imported component records the selected identity and source-file digest. That association does not verify the model: local geometry is marked unverified. F3Z, SAT, STL, and literal drag-and-drop from the panel are not supported in this candidate. Native placement acceptance is still in progress.</p></section>

        <section id="bom"><h2>Compare inside Fusion</h2><ol>
          <li>Open the assembly and configuration you intend to build. Resolve missing references first.</li>
          <li>In the connected FindEZ panel, open <strong>BOM</strong> and click <strong>Compare current assembly</strong>.</li>
          <li>Review the summary, warnings, part identities, required quantities, and recorded coverage.</li>
          <li>Use <strong>Export shortages CSV</strong> to save uncovered requirements locally. Review needs-review rows before treating them as confirmed purchase requirements.</li>
        </ol><p>This is a snapshot. Compare again after changing the design or inventory. Hidden parts count; suppressed subtrees are excluded when the exporter can determine suppression. Unknown suppression or incomplete references can require review. Comparing does not save a persistent CAD project or change stock.</p></section>

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
          <h3>Quantities and corrections</h3><p>Existing reservations and checkouts reduce available recorded stock. Requirements competing for the same stock cannot each count all of it. Review the assigned and missing quantities per line. Saved CAD match corrections are not enabled in this production candidate. Correct source identifiers or authorized inventory records, then compare again.</p>
          <p>Shortages exports are planning files, not purchase orders. Review needs-review rows, duplicate parts, and missing identifiers before ordering. No vendor quotes or automatic substitutions are included.</p>
        </section>

        <section id="limits"><h2>File limits & current limitations</h2>
          <ReferenceTable caption="Input limits" headings={['Input', 'Limit', 'Notes']} rows={[
            ['Web BOM upload', '5 MiB per file', 'Fusion JSON, CSV, or Excel .xlsx.'],
            ['Spreadsheet', '5,000 data rows, 200 columns, 20 worksheets', 'Only the selected worksheet is compared. Use plain values and individual units.'],
            ['Fusion JSON', '5,000 definitions and 20,000 occurrences', 'Use the add-in export schema; arbitrary JSON is not a BOM.'],
            ['Local model insertion', '100 MiB per file', 'STEP/STP or F3D, used locally inside Fusion. Not a web BOM upload.'],
          ]} /><p>Configuration, suppressed parts, missing references, and assembly structure can affect completeness. Quantities are snapshots, not a reservation or a physical stock check. The candidate does not provide hosted CAD assets, verified model previews, live pricing, purchasing, automatic design changes, or persistent project synchronization.</p></section>

        <section id="privacy"><h2>Privacy & permissions</h2><p>The Fusion panel loads its UI locally. Signing in opens your normal browser; do not enter your FindEZ password into a palette or share a pairing code you did not initiate.</p>
          <ReferenceTable caption="What leaves your computer" headings={['Action', 'Data used by FindEZ']} rows={[
            ['Export FindEZ BOM', 'Writes component metadata to a local JSON file. Export alone does not upload it.'],
            ['Compare current assembly / compare JSON', 'Sends component metadata and requirements to compare with the selected inventory. Assembly geometry is not uploaded.'],
            ['Review spreadsheet columns', 'Uploads the spreadsheet to read its headers and sample rows. Comparison reads the mapped list.'],
            ['Insert local model', 'Imports a local geometry file into Fusion. The file contents are not uploaded by this action.'],
          ]} /><p>Fusion sessions are read-only, scoped to one authorized inventory, and held in memory. The backend stores hashed credentials and checks current inventory permissions. The panel receives no bearer token. Restarting Fusion requires reconnecting; explicit server revocation is available on the connection page.</p><p>CAD uses FindEZ sign-in and its own scoped connection. Integration API keys do not authorize CAD routes. For external inventory scripts, use the separate <Link href="/docs/api">API documentation</Link>. See the <Link href="/privacy">Privacy Policy</Link> for the service&apos;s broader data practices.</p></section>

        <section id="sample"><h2>Try a sample design</h2><p>Open an assembly from Fusion&apos;s Data Panel under <strong>Samples → Basic Training → 06 - Assemblies</strong>. Compare it in the connected panel or export its BOM and upload the JSON. A blank Untitled design has no parts to compare.</p><p>Samples test the workflow; their parts may not exist in your inventory and may lack exact identifiers. Missing and needs-review results can be expected. Use an editable saved copy before trying local model insertion. No sample inventory is created automatically.</p></section>

        <section id="troubleshooting"><h2>Errors & troubleshooting</h2>
          <details className={styles.responseFields}><summary>I only see Export FindEZ BOM, not Open FindEZ</summary><p>Check Scripts and Add-Ins. Version 0.1.0 is export-only. Install the workspace ZIP, confirm version 0.2.2 and its Full Path, and switch Run on. Remove the old registration and restart Fusion after replacing files. Look under Design → Utilities → Add-Ins.</p></details>
          <details className={styles.responseFields}><summary>Sign-in shows Unsupported panel command</summary><p>Update to workspace version 0.2.2. Earlier versions could mistake Fusion’s acknowledgement messages for new commands and repeatedly display this error. Stop FindEZ, replace the complete extracted files, restart Fusion, confirm 0.2.2 in Scripts and Add-Ins, and try Sign in with FindEZ again.</p></details>
          <details className={styles.responseFields}><summary>Open FindEZ says the site cannot be reached</summary><p>The initial panel should load locally, before sign-in. Version 0.2.2 includes the Windows file-URL fix. Stop FindEZ, replace the complete extracted files, restart Fusion, and confirm 0.2.2. Check that palette.html, palette.js, and palette.css are present beside FindEZ.py. If the error appears instead in your browser after clicking Sign in with FindEZ, check your internet connection and open the connection page directly.</p></details>
          <details className={styles.responseFields}><summary>Fusion says Failed to add script</summary><p>Extract the ZIP and select the inner FindEZ folder. FindEZ.py and FindEZ.manifest must sit directly inside it with those exact names. Do not select the outer download folder or a single file. Send support the exact error and folder picker screenshot if it still fails.</p></details>
          <details className={styles.responseFields}><summary>I cannot find Run, or neither command appears</summary><p>New Fusion versions use a small Run toggle in the FindEZ row; older versions have a Run button. Switch to the Design workspace, enable FindEZ, and close the manager. If it switches off or displays an error, capture that message. Searching with S cannot find a command that has not loaded.</p></details>
          <details className={styles.responseFields}><summary>The pairing code expired or the panel is not connected</summary><p>Start Sign in with FindEZ again inside Fusion. Use the new code within ten minutes and approve the same selected inventory. Confirm the code matches your panel. Return to Fusion; if the session has expired or access changed, disconnect and reconnect.</p></details>
          <details className={styles.responseFields}><summary>The inventory is empty or an expected part is missing</summary><p>Check the selected inventory and location filter, your current permissions, and the item identifiers. A catalog record is not inventory stock. Similar names do not confirm an identity. Reserved and checked-out units are not available for this comparison.</p></details>
          <details className={styles.responseFields}><summary>Compare with inventory is disabled</summary><p>Choose a supported file. For CSV or Excel, also review columns, select the worksheet, map name and quantity, and confirm that it is a flat individual-unit list.</p></details>
          <details className={styles.responseFields}><summary>The export has no parts or incomplete counts</summary><p>Open an assembly, select the intended configuration, and resolve external references. Hidden components still count; suppressed subtrees are excluded when identifiable. Review warnings and compare the requirements with your source BOM.</p></details>
          <details className={styles.responseFields}><summary>A local model fails to insert or has the wrong size</summary><p>Use an editable design and a supported STEP/STP or F3D file within the size limit. Cancel if units, dimensions, or orientation are wrong. Models remain unverified and are not automatically converted into certified manufacturer assets. Report the file format and error; do not send a private design by default.</p></details>
        </section>

        <section id="roadmap"><h2>Planned capabilities</h2><p>The current release is the first Fusion workspace candidate. The following capabilities are planned, not available controls or promises of a release date.</p>
          <ReferenceTable caption="CAD development scope" headings={['Area', 'Planned work']} rows={[
            ['Fusion workspace', 'Complete native placement acceptance, hosted model retrieval and previews, and saved/frequently used parts.'],
            ['BOM and identity', 'Persistent project and BOM versions, saved match corrections, specification checks, and design-change comparison.'],
            ['Parts and CAD assets', 'A curated manufacturer catalog with exact variants, source rights, model quality labels, validation, and incremental generation jobs.'],
            ['Pricing', 'Approved vendor offers, timestamps and currencies, pack quantities, price history, and reviewed compatible alternatives.'],
            ['Procurement', 'Purchase lists, vendor grouping, team approval, order tracking, partial receiving, and inventory reconciliation.'],
            ['Further integrations', 'Direct Onshape connection, natural-language part discovery, cost recommendations, and multi-project planning.'],
          ]} /><p>Catalog availability, owned stock, CAD geometry, and vendor offers remain distinct. A generated model or similarly named part must not silently become a verified engineering substitute. Suggested purchases and design substitutions require human review.</p></section>

        <section id="support"><h2>Support & documentation coverage</h2><p>This guide covers the public CAD downloads, Fusion workspace candidate, export-only workflow, web comparison, Onshape CSV, and current limitations. The <Link href="/cad-intelligence">public CAD Intelligence page</Link> introduces the feature; the <Link href={comparisonHref}>comparison tool</Link> uses your signed-in inventory.</p><p>Contact <a href="mailto:info@findez.ai?subject=FindEZ%20CAD%20setup%20help">info@findez.ai</a> with your operating system, Fusion version, FindEZ add-in version, the step you reached, and the exact error or a redacted screenshot. Never include passwords, access tokens, pairing codes, or private design files.</p><div className={styles.footerLinks}><a href="#downloads">Downloads ↓</a><Link href="/cad/fusion/connect">Manage Fusion connections ↗</Link><Link href={comparisonHref}>Open comparison tool ↗</Link><Link href="/docs/api">API documentation</Link><a href="#quickstart">Back to start ↑</a></div></section>
      </main>
    </div>
  </div><FooterMarkup /></AppThemeProvider>;
}
