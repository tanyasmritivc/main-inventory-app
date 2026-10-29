"""Public answer generation, separate from private tool selection."""
import re
from app.services.completion_stream import completion_events

PREPARE_ANSWER = (
    'This is the private tool-selection phase. Call the available tools needed to answer '
    'the user or prepare requested actions. Do not write the user-facing answer or a '
    'preamble in this phase. When the evidence and action receipts are sufficient, or '
    'a clarification is needed, respond with only READY. A separate tool-free pass '
    'will write the answer. Never repeat an action already confirmed by a receipt.'
)
FINAL_ANSWER = (
    'Tool selection is complete. Write the final user-facing answer now, directly '
    'from the available evidence and receipts. Do not output READY, planning, tool '
    'markup or a preamble. No tools or further actions are available in this pass. '
    'Do not claim a completed change without a confirmed receipt. A pending card '
    'is not a saved change. Do not promise or describe a card that does not exist. '
    'If evidence is missing, state the limitation or ask a concise question. '
    'Use plain names for navigation; do not invent findez:// links.'
)


def _links(text, allowed, final=False):
    if allowed is None:
        return text
    # Hold only an unfinished Markdown link so an invented internal destination
    # cannot flash as a clickable URL and then be replaced at completion.
    if not final:
        start = text.rfind('[')
        if start >= 0 and re.fullmatch(r'\[[^\]\n]*|\[[^\]\n]+\](?:\([^\)\n]*)?', text[start:]):
            text = text[:start]
    return re.sub(r'\[([^\]]+)\]\((findez://[^)]+)\)',
        lambda m: m.group(0) if m.group(2) in allowed else m.group(1), text)


def stream_final_answer(response, *, validate, allowed_links=None):
    """Forward safe provider deltas immediately; never replay or replace a prefix.

    The caller has disabled tools. Validation runs before each new prefix leaves
    the server. An interruption propagates to the existing error envelope, keeping
    the visible prefix instead of retrying a different answer over it.
    """
    answer = ''
    raw = ''
    for event in completion_events(response):
        if event['type'] == 'delta':
            raw += event['delta']
            candidate = _links(raw, allowed_links)
            validate(candidate)
            if not candidate.startswith(answer):
                raise RuntimeError('Final answer changed its streamed prefix')
            delta = candidate[len(answer):]
            answer = candidate
            if delta:
                yield {'type': 'delta', 'delta': delta}
        elif event['tool_calls']:
            raise RuntimeError('Unexpected tool call in final answer')
        else:
            final = _links(event['content'], allowed_links, final=True)
            validate(final)
            if not final.startswith(answer):
                raise RuntimeError('Final answer changed its streamed prefix')
            if len(final) > len(answer):
                yield {'type': 'delta', 'delta': final[len(answer):]}
            answer = final
    if not answer.strip():
        raise RuntimeError('Empty final answer')
    return answer
