import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/ui/liquid_surface.dart';
import 'voice_capture.dart';

class VoiceRecordingOverlay extends StatelessWidget {
  const VoiceRecordingOverlay({super.key, required this.voice});
  final VoiceCapture voice;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: .65),
          dismissible: true,
          onDismiss: voice.cancel,
          semanticsLabel: 'Cancel recording',
        ),
        Center(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: LiquidSurface(
                  radius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedBuilder(
                      animation: voice,
                      builder: (context, _) => SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                voice.ready
                                    ? 'Now recording'
                                    : 'Starting microphone...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (voice.soundLevel != null)
                              ValueListenableBuilder<double>(
                                valueListenable: voice.soundLevel!,
                                builder: (context, value, _) =>
                                    _SoundBars(level: voice.ready ? value : 0),
                              )
                            else
                              const _SoundBars(level: 0),
                            const SizedBox(height: 18),
                            Text(
                              voice.transcript.isEmpty
                                  ? 'Speak naturally. Your message sends when you finish.'
                                  : voice.transcript,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: voice.cancel,
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  onPressed: voice.ready
                                      ? () => unawaited(voice.release())
                                      : null,
                                  icon: const Icon(
                                    CupertinoIcons.stop_fill,
                                    size: 14,
                                  ),
                                  label: const Text('Send'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Real microphone levels drive these bars; silence remains still.
class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.level});
  final double level;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          15,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 90,
              ),
              width: 4,
              height:
                  5 +
                  (level.clamp(0, 35) / 35) *
                      50 *
                      (.35 + .65 * math.sin((i + 1) * 1.7).abs()),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
