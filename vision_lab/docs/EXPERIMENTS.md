# First experiment and the order after it

The model choices are confirmed by Tanya. This plan prepares experiments around
SAM 2.1 Hiera Large, Depth Anything V2 Base, Qwen3-VL-8B and HunyuanOCR.
The bulk OCR engine's exact name still needs an operator record.

## 1. Build a diagnostic benchmark before training

Start with 20-30 independently owned scenes to debug labeling and transforms.
Then expand to a benchmark sized around the actual failure categories. An initial
100-200 independent scenes is a planning target, not a statistical guarantee or
an automatic release threshold. Include touching objects, tiny components,
reflective surfaces, transparency, low light, unfamiliar objects and negatives.

Assign related physical objects and capture sessions together. Have a second
person review ambiguous masks and a sample of ordinary masks. Resolve policy
disagreements before freezing the dataset. Record a new dataset version for
changes; never quietly rewrite the reference behind a published score.

**Why:** More photos do not help if they repeat the same scene or contain wrong
answers. A modest, carefully labeled benchmark tells us where to spend GPU time.

## 2. Measure two separate baselines

| Protocol | Input | What it tells us |
| --- | --- | --- |
| `sam_fixed_box` | Same images and fixed, reviewed object boxes for both checkpoints | Whether SAM draws better masks when object locations are known |
| `find_end_to_end` | Images only, using the current FIND pipeline | Whether users get more correctly separated and identified objects |

Fixed boxes must be computed once from the frozen annotations, recorded and
reused unchanged. Ground-truth-derived prompts must never be advertised as
automatic object detection. Keep baseline and candidate precision, input
resolution, prompting, postprocessing and timing boundaries identical.

The GPU adapter must return original-image binary masks and the coordinate
transforms used. Current API crops and boxes alone cannot reconstruct accurate
segmentation ground truth. Implementing the private FIND adapter requires its
source or a documented interface from the operator.

**Why:** A segmentation improvement can be hidden by bad object proposals.
Conversely, better proposals can improve the product without changing SAM.

## 3. Run a small SAM smoke experiment

Use the official [SAM 2 training code](https://github.com/facebookresearch/sam2/blob/main/training/README.md)
at a pinned commit in an isolated environment. The export follows its
[`PNGRawDataset` layout](https://github.com/facebookresearch/sam2/blob/main/training/dataset/vos_raw_dataset.py).
The [PNG segment loader](https://github.com/facebookresearch/sam2/blob/main/training/dataset/vos_segment_loader.py)
reads per-pixel object IDs; the local export test checks those IDs survive its
palette conversion.
Configure one frame per image (`num_frames=1`), separate train/validation lists
and the correct Hiera Large architecture/checkpoint.

The operator must adapt and inspect the actual configuration. The upstream
MOSE example uses a different task/resource setup; it is not a ready-made
training command for this server. Verify the exported PNG loader, object IDs,
augmentations, batch dimensions and empty-scene policy before the first step.

Start with a tiny owned training subset and a small step budget. Check that
loss is finite, gradients exist, a checkpoint saves and reloads, and memory
use stays within the agreed allocation. Then run the same baseline protocol
with the saved checkpoint. This smoke run proves the training path operates;
it does not prove generalization.

**Why:** An hour spent checking data and checkpoint loading can prevent days
of training the wrong task or disturbing inference.

## 4. Use a reviewed experiment specification

Copy `configs/sam-job.template.json` and fill in the operator's real paths,
hashes, source commit, budget and verification fields. Then run:

```sh
vision_lab/.venv/bin/findez-vision plan JOB.json --snapshot EXPORT_DIR/snapshot.json --ledger CURRENT_LEDGER.json
```

The command checks local files, checksums, a clean pinned upstream checkout and
current data permission. It lists unresolved inputs. It does **not** start
training, enforce runtime limits, reserve GPU memory or prove CUDA compatibility.
The operator must apply real runtime/resource limits in his job environment.

Separate inference and training processes, service accounts and storage.
Use approved spare capacity or a maintenance window. No production database
credentials or general customer storage access belong in the training worker.
Do not run an unreviewed configuration merely because its hash is recorded.

## 5. Compare before considering promotion

Return:

- Exact input snapshot/dataset hashes, source revision, model/config hashes.
- Training seed, optimizer, learning rate, steps, precision and environment lock.
- Baseline and candidate predictions for the same held-out images.
- Per-condition failures, memory use, synchronized latency, errors and OOM count.
- Checkpoint hash, location, license/provenance record and previous checkpoint
  reference for rollback.

Set acceptance tolerances **before** seeing candidate scores. The draft policy
is intentionally not approved. Add rules for required condition slices and
runtime metrics as well as overall recall/F1. Interpret uncertainty and sample
coverage; this v1 tool does not calculate confidence intervals.

Only a separately authorized human can approve promotion. A passing comparison
does not upload a checkpoint or change the production service. Test loading and
rollback in an isolated environment first.

## 6. Decide the next component from evidence

1. **Depth:** compare the same end-to-end pipeline with and without depth. Measure
   separation, crop usability, identity accuracy and runtime. Retain it only when
   useful; resolve the confirmed Base model's license basis.
2. **Recognition:** build independently verified identities, attributes and
   uncertainty cases. Evaluate Qwen3-VL-8B on unseen physical objects. Investigate
   [official fine-tuning/LoRA support](https://github.com/QwenLM/Qwen3-VL/blob/main/qwen-vl-finetune/README.md)
   only after masks/crops are adequate. This toolkit does not export a Qwen
   training dataset or run a recognition trainer.
3. **OCR:** use exact human transcriptions of labels and part numbers. Measure
   transcription and field extraction separately. Do not use Hunyuan outputs as
   training targets for another model without an applicable rights basis.
4. **Automation:** add scheduling only after manual runs are reproducible and
   production consent, deletion, lineage and worker isolation are implemented.

The local evaluator already supports conditional identity/OCR metrics to help
diagnose errors. That is preparation for later work, not a completed trainer
for every model.
