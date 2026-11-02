# Codex prompt: voice input in the composer (Flutter)

Before you run this, put `findez-voice.html`, `walkthrough.mp4` and `voice-states.png` into `docs/voice-v1/` in the repo. Then paste everything below the line into Codex from the repo root.

---

MOBILE (FLUTTER) ONLY. Replace the "Now recording" dialog with voice input that happens inside the Ask composer, as shown in `docs/voice-v1/findez-voice.html` and `docs/voice-v1/walkthrough.mp4`. They are the source of truth for layout, copy and timing.

## Scope

- Do not change the FastAPI backend, Supabase, the web app, env files or CI.
- Reuse the existing recording and transcription code. Only the UI and the send flow change.
- Remove the old recording dialog only where nothing else uses it.
- Work on a new branch `feat/voice-in-composer`. Do not push.

## Behaviour

1. **Start.** Tapping the mic does not open a dialog. The same composer grows from 136pt to 178pt tall (600ms).
   - The headline and suggestion chips behind it fade to 28% opacity. Nothing covers the screen.
   - The + and mic icons fade out.
2. **Listening.**
   - The top of the composer shows a small status row: a pulsing red dot and "Listening".
   - Below it, the transcript appears word by word as it is recognised. A word still being recognised shows in secondary grey, then settles to the primary text colour.
   - If the current recogniser has no partial results, show the full transcript as soon as it returns, with the same fade-in.
3. **Controls row** at the bottom of the composer:
   - **Left:** a round × button (40pt) that cancels and discards the recording.
   - **Middle:** a live waveform with 3pt bars and 3pt gaps. It scrolls left and its height follows the real microphone level. Older bars are more transparent.
   - **Right of the waveform:** a timer in mono ("0:04").
   - **Right:** a round send button (44pt) with an up arrow, in solid ink. Tapping it sends immediately.
4. **Auto-send after a pause.** When speech stops, keep the existing silence detection or use about 1.2s of silence.
   - The status changes to "Sending · tap text to edit".
   - A thin ring around the send button fills over 2 seconds, then the message sends.
   - This replaces the unclear "sends when you finish" text and the stop-square icon.
5. **Edit.** Tapping the transcript while it is listening or counting down:
   - stops recording and the countdown;
   - makes the text editable with the keyboard;
   - changes the status to "Editing · tap send when ready".
6. **Sent.** The composer shrinks back and docks at the bottom, and the conversation starts:
   - the user bubble shows the transcript, with a small mic icon and "Voice · 0:04" under it;
   - the normal answer follows.
7. **Errors.**
   - If microphone permission is denied, show the system prompt once. After that, show a one-line message in the composer: "Microphone access is off. Turn it on in Settings."
   - If nothing was heard, return to the idle composer with no message sent.

## Visual

- Match the current Ask screen in both light and dark mode.
  - **Dark:** composer `#1C1C1E` with a 1pt `#3A3A3C` line while recording. Secondary text `#8E8E93`.
  - **Light:** composer white, with a 1pt `#E2E2E2` line and a soft shadow while recording.
- Text:
  - transcript: Inter 19pt, line height 1.38;
  - status: Inter 13pt/500;
  - timer: mono 13pt.
- Motion:
  - one curve, `Cubic(0.32, 0.72, 0, 1)`;
  - words fade in with a 4pt rise and a 4 → 0 blur over 450ms;
  - **Reduce Motion:** no blur and no growth animation.
- Add a light haptic when recording starts and when the message sends.

## Check before you finish

- `flutter analyze` passes.
- On a device, in light and dark mode, check each path:
  - speak and let it auto-send;
  - tap send early;
  - tap × to cancel;
  - tap the text to edit, then send;
  - deny microphone permission;
  - stay silent.
- Commit on `feat/voice-in-composer` and list the files changed.
