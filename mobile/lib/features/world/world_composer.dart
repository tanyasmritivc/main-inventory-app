import '../../core/app_theme.dart';
import 'smooth_typing_hint.dart';
import '../chat/voice_composer_session.dart';
import '../chat/voice_composer_panel.dart';
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
    this.voiceSession,
    required this.onSend,
    this.onStop,
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
  final VoidCallback? onAttach, onVoice, onSend, onStop;
  final VoidCallback? onVoiceStart, onVoiceEnd, onVoiceCancel;
  final String voiceTranscript;
  final VoiceComposerSession? voiceSession;
  final bool busy, listening, compact;
  @override
  State<WorldComposer> createState() => _WorldComposerState();
}

class _WorldComposerState extends State<WorldComposer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
  late final AnimationController _typing;
  bool _showHint = false;
  int _idea = 0;
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
    _typing = AnimationController(vsync: this)
      ..addStatusListener(_typingStatus);
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
    _erasing = false;
    _typing.stop();
    _typing.value = 0;
    _showHint = false;
    if (mounted) setState(() {});
    if (_canAnimate) _timer = Timer(const Duration(seconds: 3), _type);
  }

  void _type() {
    if (!mounted || !_canAnimate) return;
    setState(() => _showHint = true);
    _typing.duration = Duration(milliseconds: _ideas[_idea].length * 60);
    _typing.reverseDuration = Duration(milliseconds: _ideas[_idea].length * 28);
    _typing.forward(from: 0);
  }

  void _typingStatus(AnimationStatus status) {
    if (!mounted || !_canAnimate) return;
    if (status == AnimationStatus.completed) {
      _timer = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_canAnimate) return;
        _erasing = true;
        _typing.reverse();
      });
    } else if (status == AnimationStatus.dismissed && _erasing) {
      _erasing = false;
      setState(() => _idea = (_idea + 1) % _ideas.length);
      _timer = Timer(const Duration(milliseconds: 350), _type);
    }
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
    _typing.dispose();
    widget.controller.removeListener(_reset);
    widget.focusNode.removeListener(_reset);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.voiceSession;
    if (voice == null) return _idleComposer(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: voice,
      builder: (context, _) {
        final content = AnimatedSwitcher(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 350),
          switchInCurve: voiceCurve,
          switchOutCurve: voiceCurve,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previous.map(
                (child) => Positioned.fill(
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(child: child),
                  ),
                ),
              ),
              if (current != null) current,
            ],
          ),
          child: voice.active
              ? _ComposerSurface(
                  key: const ValueKey('voice-composer-active'),
                  active: true,
                  child: VoiceComposerPanel(session: voice),
                )
              : ConstrainedBox(
                  key: const ValueKey('voice-composer-idle'),
                  constraints: BoxConstraints(
                    minHeight: widget.compact ? 104 : 136,
                  ),
                  child: _idleComposer(context),
                ),
        );
        if (reduced) return content;
        return AnimatedSize(
          duration: const Duration(milliseconds: 600),
          curve: voiceCurve,
          alignment: Alignment.topCenter,
          child: content,
        );
      },
    );
  }

  Widget _idleComposer(BuildContext context) {
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
            if (widget.voiceSession?.errorText != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.voiceSession!.errorText!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                letterSpacing: 0,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: !_showHint
                    ? (widget.compact
                          ? 'Ask FindEZ…'
                          : 'Describe your inventory…')
                    : null,
                hint: !_showHint
                    ? null
                    : Semantics(
                        label: widget.compact
                            ? 'Ask FindEZ'
                            : 'Describe your inventory',
                        child: ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: _typing,
                            builder: (context, _) => SmoothTypingHint(
                              text: _ideas[_idea],
                              visibleCharacters:
                                  _typing.value * _ideas[_idea].length,
                            ),
                          ),
                        ),
                      ),
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
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
                Tooltip(
                  message: widget.listening
                      ? 'Send voice message'
                      : 'Tap to speak',
                  triggerMode: TooltipTriggerMode.manual,
                  child: GestureDetector(
                    onLongPressStart: widget.onVoiceStart == null
                        ? null
                        : (_) => widget.onVoiceStart!(),
                    onLongPressEnd: widget.onVoiceEnd == null
                        ? null
                        : (_) => widget.onVoiceEnd!(),
                    child: IconButton(
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
                if (widget.onSend != null ||
                    widget.busy ||
                    widget.onStop != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: widget.onStop != null
                        ? 'Stop response'
                        : 'Send message',
                    onPressed: widget.onStop ?? widget.onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      disabledBackgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .06),
                    ),
                    icon: widget.busy || widget.onStop != null
                        ? SizedBox(
                            width: 19,
                            height: 19,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: widget.onStop != null
                                      ? Theme.of(context).colorScheme.surface
                                      : null,
                                ),
                                if (widget.onStop != null)
                                  const Icon(CupertinoIcons.stop_fill, size: 8),
                              ],
                            ),
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
  const _ComposerSurface({super.key, required this.child, this.active = false});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.all(Radius.circular(active ? 26 : 20));
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color:
            (dark
                    ? Color(active ? 0xFF1C1C1E : 0xFF262626)
                    : AppTheme.lightSurface)
                .withValues(alpha: !dark || active || highContrast ? 1 : .78),
        boxShadow: active && !dark
            ? [
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
        borderRadius: radius,
        border: Border.all(
          color: !dark
              ? AppTheme.controlBorder(context)
              : active
              ? const Color(0xFF3A3A3C)
              : Colors.white.withValues(alpha: highContrast ? .45 : .07),
          width: !dark || active ? 1 : .5,
        ),
      ),
      child: child,
    );
    if (active) return surface;
    return ClipRRect(
      borderRadius: radius,
      child: highContrast || active
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: surface,
            ),
    );
  }
}
