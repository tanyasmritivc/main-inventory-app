import '../onboarding/sample_scan.dart' show TrialCameraPulse;
import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A quiet, two-row composer. All capture and voice behavior belongs to Chat.
class WorldComposer extends StatefulWidget {
  const WorldComposer({
    super.key,
    this.attachmentKey,
    this.onFirstCamera,
    this.sourceChips,
    this.menuOpen = false,
    this.onSourceSelected,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onAttach,
    required this.onVoice,
    this.onVoiceStart,
    this.onVoiceEnd,
    this.onVoiceCancel,
    this.voiceTranscript = '',
    required this.onSend,
    required this.busy,
    required this.listening,
    required this.compact,
  });
  final GlobalKey? attachmentKey;
  final VoidCallback? onFirstCamera;
  final Widget? sourceChips;
  final bool menuOpen;
  final ValueChanged<String>? onSourceSelected;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAttach, onVoice, onSend;
  final VoidCallback? onVoiceStart, onVoiceEnd, onVoiceCancel;
  final String voiceTranscript;
  final bool busy, listening, compact;
  @override
  State<WorldComposer> createState() => _WorldComposerState();
}

class _WorldComposerState extends State<WorldComposer>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _hint;
  int _idea = 0, _length = 0;
  bool _erasing = false, _active = true, _enabled = false;
  static const _ideas = [
    'Where did I put my drill?',
    'Organize my pantry',
    'Add items from a photo',
    'What needs restocking?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_reset);
    widget.focusNode.addListener(_reset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    _reset();
  }

  @override
  void didUpdateWidget(WorldComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_reset);
      widget.controller.addListener(_reset);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_reset);
      widget.focusNode.addListener(_reset);
    }
    if (oldWidget.busy != widget.busy ||
        oldWidget.listening != widget.listening ||
        oldWidget.controller != widget.controller ||
        oldWidget.focusNode != widget.focusNode) {
      _reset();
    }
  }

  bool get _canAnimate =>
      _enabled &&
      _active &&
      !widget.busy &&
      !widget.listening &&
      !widget.focusNode.hasFocus &&
      widget.controller.text.isEmpty;

  void _reset() {
    _timer?.cancel();
    _hint = null;
    _length = 0;
    _erasing = false;
    if (mounted) setState(() {});
    if (_canAnimate) _timer = Timer(const Duration(seconds: 3), _type);
  }

  void _type() {
    if (!mounted || !_canAnimate) return;
    final idea = _ideas[_idea];
    _length += _erasing ? -1 : 1;
    setState(() => _hint = idea.substring(0, _length));
    var delay = Duration(milliseconds: _erasing ? 25 : 65);
    if (_length == idea.length) {
      _erasing = true;
      delay = const Duration(seconds: 3);
    } else if (_length == 0) {
      _erasing = false;
      _idea = (_idea + 1) % _ideas.length;
      delay = const Duration(milliseconds: 350);
    }
    _timer = Timer(delay, _type);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.onVoiceCancel?.call();
    _active = state == AppLifecycleState.resumed;
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_reset);
    widget.focusNode.removeListener(_reset);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible =
        View.of(context).viewInsets.bottom > 0 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
    return _ComposerSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.sourceChips != null) ...[
              widget.sourceChips!,
              const SizedBox(height: 8),
            ],
            if (widget.listening)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.voiceTranscript.isEmpty
                      ? 'Listening... Release to send'
                      : widget.voiceTranscript,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              minLines: widget.compact ? 1 : 2,
              maxLines: widget.compact ? (keyboardVisible ? 1 : 2) : 4,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              onTapOutside: (_) => widget.focusNode.unfocus(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.3,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText:
                    _hint ??
                    (widget.compact
                        ? 'Ask FindEZ…'
                        : 'Describe your inventory…'),
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                  height: 1.4,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: widget.compact ? 12 : 14),
            Row(
              children: [
                IconButton(
                  key: widget.attachmentKey,
                  tooltip: widget.menuOpen
                      ? 'Close attachment menu'
                      : 'Capture or attach',
                  onPressed: widget.onAttach,
                  icon: Icon(
                    widget.menuOpen
                        ? CupertinoIcons.xmark
                        : CupertinoIcons.plus,
                    size: 19,
                  ),
                ),
                if (widget.onFirstCamera != null)
                  TrialCameraPulse(
                    child: IconButton(
                      tooltip: 'Snap a shelf',
                      onPressed: widget.onFirstCamera,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    ),
                  ),
                const Spacer(),
                if (widget.focusNode.hasFocus)
                  IconButton(
                    tooltip: 'Hide keyboard',
                    onPressed: widget.focusNode.unfocus,
                    icon: const Icon(Icons.keyboard_hide_outlined, size: 21),
                  ),
                Semantics(
                  button: true,
                  label: widget.listening
                      ? 'Send voice message'
                      : 'Voice input. Hold to speak, release to send',
                  onTap: widget.onVoice,
                  child: Listener(
                    onPointerDown: widget.onVoiceStart == null
                        ? null
                        : (_) => widget.onVoiceStart!(),
                    onPointerUp: widget.onVoiceStart == null
                        ? null
                        : (_) => widget.onVoiceEnd?.call(),
                    onPointerCancel: (_) => widget.onVoiceCancel?.call(),
                    child: ExcludeSemantics(
                      child: AbsorbPointer(
                        child: IconButton(
                          tooltip: widget.listening
                              ? 'Release to send'
                              : 'Hold to speak',
                          onPressed: widget.onVoice,
                          icon: Icon(
                            widget.listening
                                ? CupertinoIcons.mic_fill
                                : CupertinoIcons.mic,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.onSend != null || widget.busy) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: widget.onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      disabledBackgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .06),
                    ),
                    icon: widget.busy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(CupertinoIcons.arrow_up),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A flat frosted writing surface, without the bevel used on floating controls.
class _ComposerSurface extends StatelessWidget {
  const _ComposerSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    const radius = BorderRadius.all(Radius.circular(20));
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF262626) : const Color(0xFFFFFFFF))
            .withValues(alpha: highContrast ? 1 : .78),
        borderRadius: radius,
        border: Border.all(
          color: (dark ? Colors.white : const Color(0xFF373737)).withValues(
            alpha: highContrast ? .45 : (dark ? .07 : .08),
          ),
          width: .5,
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: radius,
      child: highContrast
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: surface,
            ),
    );
  }
}
