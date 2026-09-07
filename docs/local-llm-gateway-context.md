# Local LLM gateway — context for Codex / OpenCode

Everything known about the private inference gateway, what FindEZ needs from it, and the
exact code change required to switch the app off OpenAI. Written to be pasted into another
AI editor as context.

---

## 1. The gateway

Provided by the VM owner, running on a private server with 4× NVIDIA RTX 6000 Blackwell.

| | |
|---|---|
| **Base URL** | `https://agent-gateway.openstack.ftctools.com/codingagent/v1` |
| **Protocol** | OpenAI-compatible (`/v1/chat/completions`) |
| **Auth** | Bearer API key, stored in the `MYAGENT_API_KEY` environment variable — **never commit it** |
| **Provider ID** | `myagent` |
| **Coding model** | `deepseek-v4-flash-coding` (DeepSeek V4 Flash 0731 — 284B MoE, ~13B active, 1M context) |

It is **not a single model.** It is a router in front of four or more models, and it picks
one based on the prompt. Confirmed capabilities:

- Text / coding — DeepSeek V4 Flash
- Image **generation**
- Video **generation**
- Image **OCR** — reads text out of an image
- **Whisper** — speech-to-text, reportedly good, handles Tamil

Confirmed gap, stated by the owner: **"I don't have an image classifier."**

Server-side extras that OpenAI's tooling doesn't offer: a Python sandbox **with network
access**, and a stateful browser (navigate, click, keep session). These exist because it's a
private instance where debugging features that would be a security risk publicly can be
left on.

### OpenCode config

`opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myagent": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "myagent",
      "options": {
        "baseURL": "https://agent-gateway.openstack.ftctools.com/codingagent/v1",
        "apiKey": "{env:MYAGENT_API_KEY}"
      },
      "models": { "deepseek-v4-flash-coding": { "name": "deepseek-v4-flash-coding" } }
    }
  }
}
```

**OpenCode is a developer tool, not part of the product.** It replaces Claude/Codex in the
terminal. It has nothing to do with the AI features inside the FindEZ app. Those are two
separate migrations that happen to point at the same gateway.

---

## 2. What FindEZ needs from a model

All AI calls live in `backend/app/services/openai_service.py`. Three distinct jobs:

### Job A — text agent (chat → database write)

`POST /ai_command`. Turns "add 20 M3x10 screws to the Workshop" into a tool call that writes
a row. Uses OpenAI **function calling** and streams the reply over SSE.

The hard part is not parsing the sentence — it's disambiguating against inventory that
already exists, so "screws" doesn't collapse three different screw sizes into one row.

**DeepSeek V4 Flash has been tested on this and does it well.** This job is ready to move.

### Job B — photo extraction (the blocker)

`POST /inventory/extract_from_image` and `/extract_from_image`. A photo of a pile of
robotics parts goes in; structured JSON comes out — one `ExtractedInventoryItem` per part,
with `name`, `brand`, `part_number`, `category`, `subcategory`, `quantity`, `confidence`.

The model must return `null` rather than invent a brand or part number. Categories are
robotics-first: `Robot Parts`, `Hardware`, `Tools`, `Raw Materials`, `Batteries`, `Safety`.

**This is the job the gateway cannot currently do.** See section 4.

### Job C — barcode interpretation

`POST /process_barcode`, `/barcode_lookup`. Text-only — a barcode number is looked up
externally, and the model normalises the result. The camera decodes the barcode on-device;
no model sees the image. **Text-only, so it can move now.**

### Current model configuration

`backend/app/core/config.py`:

```python
openai_model: str = "gpt-5-mini"
openai_vision_model: str = "gpt-4o"
```

Call sites in `services/openai_service.py`:

| Line | Model | Job |
|---|---|---|
| 98, 178, 316, 501 | `settings.openai_vision_model` | Vision — file analysis, single extract, multi extract |
| 248, 660, 691 | `settings.openai_model` | Text — chat agent, barcode, activity summaries |
| 347, 531, 608 | **hardcoded** `"gpt-4o-mini"` | Repair/fallback paths |
| `ai_memory.py:58` | **hardcoded** `"gpt-4o-mini"` | Background fact extraction |

Those four hardcoded pins are deliberate — reasoning models reject system prompts and return
400. They must be changed too, but consciously.

---

## 3. The one code change that unblocks everything

`backend/app/services/openai_service.py:19`:

```python
def _client() -> OpenAI:
    return OpenAI(api_key=settings.openai_api_key)
```

**There is no `base_url`.** Every call goes to OpenAI because the client has nowhere else to
go. This is the single line standing between FindEZ and any self-hosted model.

The fix is small: add an optional `openai_base_url` setting, pass it through, and leave it
unset so behaviour on OpenAI is unchanged.

Everything else is already compatible. Images are sent as base64 data URLs in the standard
OpenAI content-part shape:

```python
{"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}", "detail": "high"}}
```

Any OpenAI-compatible vision endpoint accepts this unmodified.

**Recommended sequence** — text first, vision second, because text is proven and vision is not:

1. Add `openai_base_url` (additive, default unset)
2. Point `openai_model` at `deepseek-v4-flash-coding`, keep `openai_vision_model` on `gpt-4o`
3. Verify Job A and Job C on a device
4. Only then move vision

---

## 4. The vision gap — what to ask for

The gateway has **OCR**, which is not what Job B needs.

- **OCR** answers *"what text is in this image?"* — good for a printed SKU on a label
- **Job B** answers *"what parts are these, what are they called, how many, what category?"* —
  requires recognising objects and reasoning about them, then emitting JSON

An OCR model given a photo of loose standoffs and screws returns nothing useful, because
there is often no text to read. This is why "I don't have an image classifier" is the
blocker — though strictly what's needed is not a classifier either. A classifier picks one
label from a fixed list. Job B needs a **vision-language model (VLM)**: a model that takes
an image *and* a text prompt and writes a structured answer.

### The ask

> Can you serve an open-weight **vision-language model** on the gateway, with an
> OpenAI-compatible `/chat/completions` endpoint that accepts `image_url` content parts as
> base64 data URLs, and supports either function calling or JSON-mode output?

Current open-weight candidates that fit, all servable on the existing GPUs via vLLM:

| Model | Note |
|---|---|
| **Qwen2.5-VL-72B** | Strongest all-round open-weight VLM; very strong OCR benchmark scores, which also helps read vendor SKUs |
| **InternVL3-78B** | Strongest MIT-licensed option — matters if licensing is a concern |
| **Llama 4 Maverick** | Highest MMMU of the open-weight set |
| **Pixtral 12B** (Mistral) | Much smaller; worth testing first because it's cheap to serve |

Suggested approach: start with a smaller model like Pixtral to prove the plumbing end to
end, then measure quality against `gpt-4o` on the same photos before committing.

### What to send with the ask

`docs/local-llm-eval-pack.md` already contains the verbatim production prompts and JSON
schemas for these jobs. Pair it with real photos of FTC/FRC parts and the exact JSON
`gpt-4o` returns for each, so quality can be compared directly rather than by impression.

---

## 5. Things that will bite

- **Function calling is the risk, not vision.** Job A depends on the model reliably emitting
  well-formed tool calls. Open-weight models vary a lot here. Test with malformed and
  ambiguous input, not just the happy path.
- **`gpt-4o-mini` is pinned at four sites** for a reason. Don't bulk-replace them.
- **Never call a model with an empty prompt and forced `tool_choice`.** This already caused a
  bug where the inventory page appeared empty — the model invented a filter from nothing.
- **Guard on empty input** everywhere, for the same reason.
- The gateway is on the same private network as everything else. If it becomes a hard
  dependency of the product, the app is down whenever that server is. Decide whether OpenAI
  stays as a fallback path before removing it.
