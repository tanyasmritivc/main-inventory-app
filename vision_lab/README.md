# FindEZ Vision Lab

Local preparation for a permission-aware vision learning system.
Nothing in this package connects to FindEZ production, the GPU server or a cloud
model. It cannot deploy a checkpoint or start training. The user has explicitly
withheld deployment approval.

## Start here

We are building the tools that make a future experiment trustworthy:

1. **Collect examples you own.** An image is the question we ask the model.
2. **Draw and check the correct answers.** A mask marks which pixels belong to
   one object. Two touching motors need two separate masks.
3. **Keep practice and exam images separate.** Training teaches; validation helps
   choose settings; the held-out test set measures the final result.
4. **Record permission.** Owning a photo and verifying its labels are separate
   decisions. This pilot only accepts creator-owned or generated synthetic data.
5. **Measure a baseline.** This is the current system's score before changing it.
6. **Give the GPU operator a reproducible package.** He supplies verified server
   details, runs the experiment later, and returns predictions and measurements.

The included demo contains colored rectangles, not customer photos. Its scores
prove the tools can distinguish correct masks from merged masks. They do **not**
measure SAM or FindEZ accuracy.

**What does "label" mean here?** In training, a label is the checked answer,
not merely an item's name. A segmentation label is an object's pixel boundary;
an identity label says what the object is; an OCR label is the exact text visible
on it. The first experiment targets object separation and boundaries. Identity,
attributes and text belong to later recognition/OCR experiments. In the editor,
the short "Object name or category" field is just one part of the annotation.

## Install and practice on this Mac

From the repository root, with Python 3.11 or newer:

```sh
python3 -m venv vision_lab/.venv
vision_lab/.venv/bin/python -m pip install Pillow==13.0.0 setuptools==82.0.1
vision_lab/.venv/bin/python -m pip install --no-build-isolation --no-deps -e vision_lab
vision_lab/.venv/bin/findez-vision demo vision_lab/workspace/practice
vision_lab/.venv/bin/findez-vision validate vision_lab/workspace/practice/dataset.json --verified --ledger vision_lab/workspace/practice/grants.json
vision_lab/.venv/bin/findez-vision serve vision_lab/workspace/practice/dataset.json
```

Open `http://127.0.0.1:8790`. Keep the terminal running; Ctrl+C stops it.
The server listens only on this computer. It is a single-operator local tool,
not a hosted annotation service. Do not expose it through a tunnel.

Click an object in the right-hand list to edit its label or drag boundary points.
To add an object, click around its visible outline, then press **Finish polygon**.
Use **Save draft** while working. Tick the review checkbox and enter your name
only after checking every visible object, then press **Save as verified**.
Incomplete outlines must be finished or discarded before saving.

Binary PNG masks can represent holes and intricate shapes. This polygon editor
opens those samples read-only because it cannot display their mask overlays.
Use an external mask editor and the documented file format for those samples.

**Why save explicitly?** Verification should be a deliberate decision. Ordinary
edits do not automatically become approved training examples. Local `.history`
files preserve previous annotations for review.

## See how evaluation works

Run these against a **fresh, unedited demo**. An edit changes its fingerprint,
so the provided predictions will correctly stop matching that dataset revision.

```sh
vision_lab/.venv/bin/findez-vision evaluate vision_lab/workspace/practice/dataset.json vision_lab/workspace/practice/predictions-good.json --ledger vision_lab/workspace/practice/grants.json --output vision_lab/workspace/results/good.json
vision_lab/.venv/bin/findez-vision evaluate vision_lab/workspace/practice/dataset.json vision_lab/workspace/practice/predictions-merged.json --ledger vision_lab/workspace/practice/grants.json --output vision_lab/workspace/results/merged.json
vision_lab/.venv/bin/findez-vision compare vision_lab/workspace/results/merged.json vision_lab/workspace/results/good.json --policy vision_lab/workspace/practice/gate-policy.draft.json --output vision_lab/workspace/results/comparison.json
```

Each evaluation writes JSON for software and HTML for people. Open the HTML
files in a browser. The correct example scores higher. The comparison still
blocks release because synthetic practice data cannot qualify a real model.
An unsuccessful qualification is recorded in the comparison JSON; it is not a
shell error or an automatic deployment gate.

## Use your own photos

### Add photos in the browser

With the local editor running:

1. Save any current edits using **Save draft**.
2. Click **Add photos**, then **Choose your photos**. Select up to 20 files.
   JPEG and PNG work everywhere; on macOS, HEIC is converted locally using the
   system image converter. On Windows, export HEIC as JPEG or PNG first.
   Each photo must be at most 32 MB and 16 megapixels.
3. Expand **Photo group** and enter a short name such as `desk_objects_01`.
   Use the same group for different views of the same physical objects, even
   across later imports. This prevents related images entering different splits.
4. Check the ownership/content box only after checking the photos. Click
   **Add selected photos**. Copies are saved locally as drafts; your original
   files and existing annotations stay unchanged.
5. Select a photo. Click points around one object's visible edge, then click
   **Finish polygon**. Use more points around curves; drag saved points to adjust.
6. Enter a simple name, such as `Dry-erase marker`. Exact identity and visible
   text are optional. Transcribe only text you can actually read on that object.
7. Repeat for each visible object and click **Save draft** regularly.
8. Only after checking the whole photo, enter your reviewer name, check the
   review box and click **Save as verified**. One outlined object in a crowded
   scene is still an incomplete draft.

Start with two or three clearly visible objects on a plain surface. Take a few
angles, then repeat with different physical objects. A first batch of 30 reviewed
photos is a workflow pilot, not a guarantee that a model can improve.

An example is the photo **plus its checked outlines and descriptions**. Saving
keeps it across browser refreshes; unsaved edits are not persistent. Back up the
whole dataset folder, including `dataset.json`, `images/` and `.history/`.
There is no cloud sync.

Browser imports receive a provisional `train` split. Before any experiment,
review capture groups and physical-object relationships, then assign separate
training, validation and test sets. Do not treat the default split as a finished
benchmark. Verification does not grant training permission. The assistant-drawn
demonstration retains model-assisted provenance and is not an eligible training
example under the current export rules.

### Command-line ingestion and export

Start with a small set of objects you own, without people, addresses, private
screens or other people's documents. Do not export customer inventory images.
Photograph different objects and conditions; ten views of the same motor are
not ten independent examples.

```sh
vision_lab/.venv/bin/findez-vision ingest /absolute/path/to/owned-photo.jpg vision_lab/workspace/photo-a --id photo_a --group drawer_session_a --physical-object motor_a --split train
vision_lab/.venv/bin/findez-vision ingest /absolute/path/to/another-owned-photo.jpg vision_lab/workspace/photo-b --id photo_b --group desk_session_b --physical-object motor_b --split validation
vision_lab/.venv/bin/findez-vision assemble vision_lab/workspace/photo-a/dataset.json vision_lab/workspace/photo-b/dataset.json --id owned_pilot --output vision_lab/workspace/owned-pilot
vision_lab/.venv/bin/findez-vision serve vision_lab/workspace/owned-pilot/dataset.json
```

Replace the example paths and IDs. Keep all views of one physical object or
capture session in one split. The importer normalizes rotation, strips metadata
and creates a draft. It never grants training permission. The assembler copies
samples into one folder and checks for split leakage.

After reviewing the actual content and labels, record your own attestation:

```sh
vision_lab/.venv/bin/findez-vision grant vision_lab/workspace/owned-pilot/dataset.json vision_lab/workspace/owned-pilot/grants.json --reviewer Tanya --purpose evaluation --purpose segmentation_training --days 30 --attest-owned-and-sensitive-content-reviewed
vision_lab/.venv/bin/findez-vision export-sam vision_lab/workspace/owned-pilot/dataset.json --ledger vision_lab/workspace/owned-pilot/grants.json --output vision_lab/workspace/exports/owned-pilot-v1
vision_lab/.venv/bin/findez-vision verify-snapshot vision_lab/workspace/exports/owned-pilot-v1/snapshot.json --ledger vision_lab/workspace/owned-pilot/grants.json
```

Do not type the attestation flag until its statement is true. This local ledger
records an operator assertion; it does not authenticate customer consent.
Expired, revoked, unreviewed or model-assisted training examples are blocked.
Outputs refuse to overwrite existing versions. Use a new output name for a
new experiment. Train and validation splits both need verified, nonempty masks.

## What to read next

- [Architecture and verified gaps](docs/ARCHITECTURE.md): how the existing app
  differs from this local preparation.
- [Dataset and prediction format](docs/DATASET.md): what each field means.
- [Experiment plan](docs/EXPERIMENTS.md): what the first GPU experiment must test.
- [Permission and deletion design](docs/PERMISSIONS.md): what must exist before
  customer data can enter training.
- [Uncle handoff](docs/UNCLE_HANDOFF.md): the concrete questions and later tasks.
- [Validation receipt](docs/VALIDATION.md): actual checks and remaining limits.

## Tests

```sh
vision_lab/.venv/bin/python -m unittest discover -s vision_lab/tests
node --check vision_lab/findez_vision/web/app.js
```

Tests use generated images and temporary loopback servers. They require no API
keys, GPU, customer data, account login or production connection.

The GPU training environment is intentionally separate. Installing this package
does not install PyTorch, download model weights or claim CUDA compatibility.
