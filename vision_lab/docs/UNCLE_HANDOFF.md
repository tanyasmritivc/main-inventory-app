# Operator handoff

Prepared locally. Nothing has been sent, uploaded, trained or deployed.
Tanya controls when this work may proceed.

## Message Tanya can send first

> We have prepared local dataset review, permission checks, SAM export and
> evaluation tools for FindEZ. The models are confirmed: SAM 2.1 Hiera Large,
> Depth Anything V2 Base, Qwen3-VL-8B and HunyuanOCR. I am not asking you to
> change them or give me server credentials.
>
> Before any GPU changes, please provide the following non-secret details:
>
> 1. FIND source commit and relevant pipeline/configuration files, or a redacted
>    interface description if you cannot share the repository. Include how
>    proposals, masks, crops, depth, recognition and OCR are connected.
> 2. Weight hashes and software/configuration versions for the confirmed models,
>    plus the exact bulk OCR engine. Include any adapters or quantization.
> 3. GPU count, available training allocation, OS, driver, CUDA, PyTorch and
>    current environment lock. Can an isolated experiment run without affecting
>    production inference?
> 4. Applicable license arrangements for commercial use of Depth Anything V2
>    Base and HunyuanOCR, including whether derived outputs may train other
>    components.
> 5. How to return original-image masks, transforms, model provenance and timing
>    for a small owned-image baseline without changing production.
> 6. Your proposed authenticated encrypted transport for the application-to-FIND
>    hop, and how it would be tested before a separately approved switch.
>
> Please return configuration facts and a proposed isolated run procedure.
> Do not make production changes yet. Do not send passwords, API keys, private
> customer images or full environment files containing secrets.

## Later, when a local package is approved for transfer

The code package should contain this directory, tests, documentation and a
generated synthetic practice set only. Exclude `.venv`, `.git`, private images,
permission ledgers for real people, tokens and model weights.

First run the tests in a **separate** Python environment. This check needs no
GPU and must not alter the production Python environment:

```sh
python3 -m venv .venv-vision-prep
.venv-vision-prep/bin/python -m pip install Pillow==13.0.0 setuptools==82.0.1
.venv-vision-prep/bin/python -m pip install --no-build-isolation --no-deps -e vision_lab
.venv-vision-prep/bin/python -m unittest discover -s vision_lab/tests
.venv-vision-prep/bin/findez-vision doctor
.venv-vision-prep/bin/findez-vision demo /absolute/path/to/new-synthetic-practice
```

`doctor` reads local environment/GPU metadata only. Review its output before
sharing. The toolkit does not download model weights or install a GPU stack.

## First GPU task after a separate go-ahead

1. Inspect the package and isolate storage/process permissions.
2. Verify approved dataset rights and snapshot hashes using the current ledger.
3. Pin the current SAM source/checkpoint and reproduce its baseline.
4. Implement the two evaluation adapters in [EXPERIMENTS.md](EXPERIMENTS.md)
   against the actual FIND source. Return predictions in [DATASET.md](DATASET.md).
5. Smoke-test the loader and one-frame training configuration with a small
   approved resource/time budget.
6. Return the evidence. Keep all candidate checkpoints outside production.

No untested YAML configuration or remote shell command is supplied here.
The exact CUDA/PyTorch stack, training allocation and private FIND interfaces
must determine that configuration.

## Return packet

- Source commit and reviewed environment lock/container digest.
- Model manifest and hashes for the baseline and candidate.
- Reviewed training configuration, seed, steps and resource limits.
- Dataset/snapshot fingerprint and permission-ledger revision checked at start.
- Original-image prediction masks and `predictions.json`, including empty results.
- Logs with secrets removed; finite-loss/checkpoint reload evidence; runtime,
  memory, errors, OOM count and timing methodology.
- Previous checkpoint reference and a proposed rollback procedure.

Do not include production credentials or unrelated customer content. Returning
this packet does not authorize promotion. Tanya reviews it before any
deployment decision.
