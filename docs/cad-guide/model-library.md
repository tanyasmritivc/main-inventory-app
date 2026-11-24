# Publishing an exact-variant model

The Fusion panel can preview and insert a reviewed model for a verified
`parts_catalog` entry. The API reads a directory controlled by the publisher.
Leave `FINDEZ_CAD_MODEL_LIBRARY` unset until reviewed assets are available.
The service account needs read access. Only publishers should have write access.

For each exact catalog UUID, create a directory under that root. Publish the
STEP and PNG first, named by their lowercase SHA-256 digests, with extensions
`.step` and `.png`. Use a STEP under 100 MiB and a single-frame PNG up to
1024 pixels per side and 512 KiB. Check the model's geometry and units in CAD
and confirm that the preview depicts that revision. The publisher records the
rights to redistribute both assets, the reviewer and the public source page.

Write `manifest.json` to a temporary file in the same directory. Rename it to
`manifest.json` after the assets are in place. This is the publication step.
Its fields are:

| Field | Value |
| --- | --- |
| catalog_id, manufacturer, part_number | Exact catalog UUID, saved brand and exact part number. Preserve punctuation and leading zeros. |
| specifications | Complete verified catalog specification object, with values as strings. |
| source, source_url | `manufacturer` or `third_party` and a public HTTPS product/model page without credentials or query parameters. |
| revision, units | The reviewed model revision and its declared `mm`, `cm`, `in` or `m` units. |
| redistribution_approved, redistribution_evidence, reviewed_by | Boolean true, the publisher's evidence reference covering STEP and preview, and the reviewer identifier. |
| step_sha256, preview_sha256 | SHA-256 digests of the two exact published files. |

To withdraw a version, remove the manifest from the published directory. To
replace a version, publish new assets and atomically replace the manifest.
An outstanding preview then requires another review before download. Each
download rechecks the current catalog record and the asset digest. These checks
establish the selected source and bytes. Independent engineering validation
and native host acceptance remain separate tasks.
