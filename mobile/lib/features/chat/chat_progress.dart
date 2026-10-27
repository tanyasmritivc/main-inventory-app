import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/app_text.dart';

/// Public work stages only; never private model reasoning.
class ChatProgress extends StatefulWidget {
  const ChatProgress({super.key, required this.message});
  final String message;
  @override
  State<ChatProgress> createState() => _ChatProgressState();
}

class _ChatProgressState extends State<ChatProgress> {
  final List<String> _steps = [];
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void didUpdateWidget(ChatProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _record();
  }

  void _record() {
    final text = widget.message.trim();
    if (text.isNotEmpty && (_steps.isEmpty || _steps.last != text)) {
      _steps.add(text);
      if (_steps.length > 30) _steps.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '${widget.message}. ${_expanded ? 'Hide' : 'Show'} progress',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      liveRegion: true,
                      child: ShinyStatusText(widget.message),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < _steps.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          index == _steps.length - 1
                              ? Icons.more_horiz
                              : Icons.check,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            _steps[index],
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Native version of the supplied React Bits 2s soft light sweep.
class ShinyStatusText extends StatefulWidget {
  const ShinyStatusText(
    this.text, {
    super.key,
    this.heading = false,
    this.style,
    this.textAlign,
  });
  final String text;
  final bool heading;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  State<ShinyStatusText> createState() => _ShinyStatusTextState();
}

class _ShinyStatusTextState extends State<ShinyStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.heading ? 4 : 2),
  );
  Timer? _pause;
  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (widget.heading && status == AnimationStatus.completed) {
        // A quiet pause between sweeps keeps the welcome screen unobtrusive.
        _pause = Timer(const Duration(seconds: 1), () {
          _pause = null;
          if (mounted &&
              !MediaQuery.disableAnimationsOf(context) &&
              TickerMode.valuesOf(context).enabled) {
            _controller.forward(from: 0);
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pause?.cancel();
      _pause = null;
      _controller.stop();
    } else if (!_controller.isAnimating && _pause == null) {
      if (widget.heading) {
        _controller.forward(from: 0);
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.heading
        ? (dark ? const Color(0xFFBDBDBD) : const Color(0xFF242424))
        : (dark ? const Color(0xFFB5B5B5) : const Color(0xFF626269));
    final shine = dark
        ? Colors.white
        : (widget.heading ? const Color(0xFF767676) : const Color(0xFF19191D));
    final text = AppText(
      widget.text,
      textAlign: widget.textAlign,
      style: (widget.style ?? const TextStyle(fontSize: 16, height: 1.4))
          .copyWith(color: base),
    );
    if (MediaQuery.disableAnimationsOf(context)) return text;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: text,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final eased = .5 - math.cos(math.pi * _controller.value) / 2;
            final center = -.22 + 1.44 * eased;
            return LinearGradient(
              begin: const Alignment(-1, .58),
              end: const Alignment(1, -.58),
              colors: [
                base,
                base,
                Color.lerp(base, shine, .5)!,
                shine,
                Color.lerp(base, shine, .5)!,
                base,
                base,
              ],
              stops: [
                0,
                (center - .2).clamp(0, 1),
                (center - .1).clamp(0, 1),
                center.clamp(0, 1),
                (center + .1).clamp(0, 1),
                (center + .2).clamp(0, 1),
                1,
              ],
            ).createShader(bounds);
          },
          child: child,
        ),
      ),
    );
  }
}
