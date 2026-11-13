# FindEZ for Fusion: private BOM comparison preview

Version 0.1.0. This is a prototype, not an Autodesk-certified marketplace release.
The add-in exports metadata to a local JSON file. It does not upload the assembly,
send geometry, request credentials, modify the design, or reserve inventory.

## Install and export

1. Extract the ZIP. Keep `FindEZ.py`, `FindEZ.manifest` and `exporter.py` together
   inside the `FindEZ` folder.
2. In Fusion's Design workspace, open Utilities > Scripts and Add-Ins. On the
   Add-Ins tab, use the add/select-folder control to select that `FindEZ` folder.
3. Select FindEZ and click Run. The Utilities panel now has **Export FindEZ BOM**.
   If the command is unavailable, switch to Design and restart the add-in.
4. Open the desired assembly/configuration, resolve external references, and run
   **Export FindEZ BOM**. Choose a local destination for the JSON file.
5. In a FindEZ deployment containing the CAD preview, choose your inventory and
   open **CAD Intelligence** (`/cad?inventory=<inventory UUID>`). Choose the JSON
   file, then click **Compare with inventory** to send its metadata for analysis.

Use the normal FindEZ browser sign-in. Never paste access tokens or passwords into
the add-in. The comparison endpoint must be deployed alongside the web page;
this source package alone does not enable it on the production website.

Stop the add-in from Scripts and Add-Ins to remove the command. Remove its entry
and delete the extracted folder to uninstall. No startup registration is enabled.

## What is exported

Document name and saved/unsaved revision, active configuration label, component
names/part numbers, source identifiers/tokens, hierarchy, occurrence visibility
and suppression evidence. The optional `FindEZ` attribute group can provide
`manufacturer`, `barcode`, and `procurement_policy` when a team already maintains
those attributes. No arbitrary custom properties are exported.

Tokens are opaque source locators, not secrets or stable identity comparisons.
Component identity is scoped by source file/version/configuration and component
ID. Source metadata is proprietary design information: review the JSON before
choosing to upload it to an inventory.

## Counting and matching limits

- Traverse contextual occurrences once; repeated nested parts retain individual
  occurrence records. Hidden parts count, suppressed subtrees do not.
- Missing suppression evidence is marked incomplete and the subtree is excluded
  from the count. Configured designs require independent verification.
- By default, a parent expands to its children and a leaf is one procurement unit.
  A component's `procurement_policy` attribute may be `purchase`, `fabricate`,
  `assembly`, `exclude` or `review`. Purchased assemblies block child procurement
  counts. Bodies directly owned by an expanded parent trigger a warning.
- No readable leaf bodies means review. A part number equal to its name is treated
  as a default, not a reliable manufacturer identifier.
- Exact barcode or manufacturer plus part-number identity may cover recorded
  quantities. Conflicting identifiers do not match. Names alone require review.
  Dimensions, material, electrical ratings and engineering compatibility are not
  established by this preview.
- Existing kit reservations and active checkouts reduce available recorded stock.
  One stock unit cannot cover two BOM lines. Reads are nontransactional and may
  become stale; the preview neither reserves units nor certifies physical counts.
- Limits: 5 MiB JSON, 20,000 occurrences, 5,000 definitions, depth 64. Large or
  unreadable exports fail visibly; they are never silently truncated.

## Private acceptance checklist

Test on your own computer without sending the design file to a developer:

- Two subassemblies with four identical screws each produce eight screws.
- Hiding a part preserves its requirement; suppressing it excludes its subtree.
- Purchased subassemblies do not count both the assembly and its children.
- Saving/dirty edits/configuration changes show the correct revision state.
- Matching parts in another inventory never appear in the selected inventory.
- A shared stock of six screws covers only six of eight required screws.
- Review warnings, missing metadata and quantities against an independently
  checked BOM. No inventory count or design file should change after comparison.

Automated tests use synthetic host objects and inventory data. Windows/macOS
Fusion installation, commands and actual assembly semantics still require native
acceptance. These tests do not imply that the prototype is ready for production.

## Developer verification

From the repository root:

```sh
python -m pytest -q backend/tests/test_cad_prototype.py
python scripts/package_fusion.py
```

The package script creates the deterministic web download from reviewed source;
it contains no credentials or compiled dependencies. Backend comparison uses the
existing Supabase user authorization and inventory permission checks. No migration
or new table is required for this stateless preview.

Official references:

- [Assembly traversal](https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/AssemblyTraversalUsingRecursion_Sample.htm)
- [Component ID scope](https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/fusion_Component_id.htm)
- [Occurrence timeline](https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/fusion_Occurrence_timelineObject.htm)
- [Document references](https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/core_DocumentReference.htm)
- [Add-in installation](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/How-to-install-an-ADD-IN-and-Script-in-Fusion-360.html)
