import 'dart:async';
import 'package:flutter/material.dart';

/// Alternate wording for the same public activity, not invented progress.
class ActivityLabel extends StatefulWidget {
  const ActivityLabel(this.message, {super.key, required this.builder});
  final String message;
  final Widget Function(String) builder;
  @override
  State<ActivityLabel> createState() => _ActivityLabelState();
}

class _ActivityLabelState extends State<ActivityLabel> {
  Timer? _timer;
  int _variant = 0;
  static List<String> alternatives(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('finding objects')) {
      return [
        message,
        'Looking for the little details...',
        'Taking a closer look at your photo...',
        'Sorting objects from the background...',
      ];
    }
    if (lower.contains('reading details') || lower.startsWith('checked ')) {
      return [
        message,
        'Getting to know these objects...',
        'A closer look at shapes and labels...',
        'Checking what each crop tells us...',
      ];
    }
    if (lower.contains('search') || lower.contains('saved items')) {
      return [
        message,
        'Looking through the relevant records...',
        'Following the clues in your saved items...',
        'Checking for a useful match...',
      ];
    }
    if (lower.contains('spaces') || lower.contains('destination')) {
      return [
        message,
        'Looking for a good place for these...',
        'Checking your available Spaces...',
        'Finding a home for the draft...',
      ];
    }
    if (lower.contains('draft')) {
      return [
        message,
        'Putting your items in order...',
        'Keeping the counts and details together...',
        'Getting the draft ready to review...',
      ];
    }
    if (lower.contains('response') ||
        lower.contains('confidence') ||
        lower.contains('review')) {
      return [
        message,
        'Bringing the details together...',
        'Making the next step clear...',
        'Putting the finishing touches on the reply...',
      ];
    }
    if (lower.contains('thinking') ||
        lower.contains('understanding') ||
        lower.contains('request') ||
        lower.contains('checking your things')) {
      return [
        message,
        'Putting the pieces together...',
        'Working out the useful next step...',
        'A little thought, then a clear answer...',
      ];
    }
    return [message];
  }

  void _schedule() {
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && alternatives(widget.message).length > 1) {
        setState(() => _variant++);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(ActivityLabel old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) {
      _variant = 0;
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = alternatives(widget.message);
    return widget.builder(words[_variant % words.length]);
  }
}

class ScanPlaceholders extends StatefulWidget {
  const ScanPlaceholders({super.key});
  @override
  State<ScanPlaceholders> createState() => _ScanPlaceholdersState();
}

class _ScanPlaceholdersState extends State<ScanPlaceholders>
    with SingleTickerProviderStateMixin {
  late final _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _shine.stop();
    } else {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _shine,
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: dark
                            ? const Color(0xff28282b)
                            : const Color(0xffe9e9ed),
                        gradient: MediaQuery.disableAnimationsOf(context)
                            ? null
                            : LinearGradient(
                                begin: Alignment(-3 + 6 * _shine.value, -1),
                                end: Alignment(-1 + 6 * _shine.value, 1),
                                colors: dark
                                    ? const [
                                        Color(0xff28282b),
                                        Color(0xff3d3d42),
                                        Color(0xff28282b),
                                      ]
                                    : const [
                                        Color(0xffe9e9ed),
                                        Color(0xfffafafd),
                                        Color(0xffe9e9ed),
                                      ],
                                stops: const [.15, .5, .85],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
