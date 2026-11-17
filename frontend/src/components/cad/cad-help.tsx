import styles from './cad.module.css';

export function FusionInstallSteps() {
  return <div className={styles.instructions}>
    <ol>
      <li><strong>Download and extract.</strong> On the computer running Fusion, download the add-in. On Windows, right-click the ZIP and choose <b>Extract All</b>. On Mac, double-click the ZIP.</li>
      <li><strong>Open the add-in manager.</strong> In Fusion&apos;s Design workspace, choose <b>Utilities → Add-Ins → Scripts and Add-Ins</b>.</li>
      <li><strong>Add the inner FindEZ folder.</strong> Click <b>+ → Script or Add-In from device</b>. Open the extracted folder, then select the <b>FindEZ</b> folder inside it.</li>
    </ol>
    <div className={styles.folderGuide}><span>Select this folder:</span><pre>{'findez-fusion-workspace/\n  FindEZ/  ← select this\n    FindEZ.py\n    FindEZ.manifest\n    exporter.py'}</pre><p>Select the folder, not the ZIP or an individual file.</p></div>
    <ol start={4}><li><strong>Switch FindEZ on.</strong> Confirm version <b>0.4.1</b>, then find the FindEZ row and turn on the small toggle in the <b>Run</b> column. Blue means it is running. In older Fusion versions, select FindEZ and click the Run button.</li></ol>
    <div className={styles.runGuide} aria-label="Example: FindEZ row with the Run switch on"><span>FindEZ</span><span>Run <i aria-hidden="true" /> <b>On</b></span></div>
    <p>Click <b>Close</b>, then choose <b>Utilities → Add-Ins → Open FindEZ</b>. Use <b>Sign in with FindEZ</b> to connect an inventory and work inside the panel. <b>Export FindEZ BOM</b> remains available for optional web comparison. Check <b>Run on Startup</b> to load FindEZ the next time you open Fusion.</p>
    <p><a href="/docs/cad#install">Full CAD documentation: installation, updates, connection and troubleshooting →</a></p>
  </div>;
}
