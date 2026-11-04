import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'voice_composer_session.dart';

const voiceCurve = Cubic(.32, .72, 0, 1);

class VoiceComposerPanel extends StatelessWidget {
  const VoiceComposerPanel({super.key, required this.session});
  final VoiceComposerSession session;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF5F5F7) : const Color(0xFF0B0B0C);
    final secondary = dark ? const Color(0xFF8E8E93) : const Color(0xFF6B6B70);
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final reduced = MediaQuery.disableAnimationsOf(context);
    const textStyle = TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontSize: 19,
      height: 1.38,
      letterSpacing: -.19,
    );
    return SizedBox(
      height: (178 + (scale - 1).clamp(0, 3) * 110).clamp(178, 480).toDouble(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: _ListeningDot(
                    listening: session.phase == VoiceComposerPhase.listening,
                  ),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      session.status,
                      style: TextStyle(
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: session.editing
                  ? TextField(
                      key: const Key('voice-editor'),
                      controller: session.editor,
                      autofocus: true,
                      style: textStyle.copyWith(color: ink),
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => session.notifyEditorChanged(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: session.capture.active
                            ? 'Transcribing...'
                            : 'Your message',
                        hintStyle: textStyle.copyWith(color: secondary),
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: 'Edit voice message',
                      child: GestureDetector(
                        key: const Key('voice-transcript'),
                        behavior: HitTestBehavior.opaque,
                        onTap: session.edit,
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            duration: const Duration(milliseconds: 450),
                            switchInCurve: voiceCurve,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: reduced
                                      ? child
                                      : AnimatedBuilder(
                                          animation: animation,
                                          child: child,
                                          builder: (_, child) =>
                                              Transform.translate(
                                                offset: Offset(
                                                  0,
                                                  4 * (1 - animation.value),
                                                ),
                                                child: ImageFiltered(
                                                  imageFilter:
                                                      ui.ImageFilter.blur(
                                                        sigmaX:
                                                            4 *
                                                            (1 -
                                                                animation
                                                                    .value),
                                                        sigmaY:
                                                            4 *
                                                            (1 -
                                                                animation
                                                                    .value),
                                                      ),
                                                  child: child,
                                                ),
                                              ),
                                        ),
                                ),
                            child: Text(
                              session.text,
                              key: ValueKey(session.text),
                              style: textStyle.copyWith(
                                color: session.partial ? secondary : ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: 'Cancel voice message',
                        onPressed: session.cancel,
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: dark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F2),
                          foregroundColor: ink,
                        ),
                        icon: const Icon(CupertinoIcons.xmark, size: 17),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 34,
                      child: CustomPaint(
                        key: const Key('voice-waveform'),
                        painter: _VoiceWavePainter(
                          session.levels.toList(),
                          ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Recorded ${session.duration.inSeconds} seconds',
                  child: Text(
                    voiceTime(session.duration),
                    textScaler: MediaQuery.textScalerOf(
                      context,
                    ).clamp(maxScaleFactor: 1.8),
                    style: TextStyle(
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CustomPaint(
                    painter: _SendRing(session.countdownProgress, ink),
                    child: Center(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton.filled(
                          key: const Key('voice-send'),
                          tooltip: 'Send voice message',
                          onPressed: session.canSend ? session.send : null,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: ink,
                            foregroundColor: dark ? Colors.black : Colors.white,
                          ),
                          icon: const Icon(CupertinoIcons.arrow_up, size: 21),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningDot extends StatefulWidget {
  const _ListeningDot({required this.listening});
  final bool listening;
  @override
  State<_ListeningDot> createState() => _ListeningDotState();
}

class _ListeningDotState extends State<_ListeningDot>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ListeningDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.listening && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, _) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.listening
            ? const Color(0xFFFF453A)
            : const Color(0xFF8E8E93),
        boxShadow: widget.listening
            ? [
                BoxShadow(
                  color: const Color(0xFFFF453A).withValues(alpha: .18),
                  spreadRadius: 5 * _pulse.value,
                ),
              ]
            : null,
      ),
    ),
  );
}

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter(this.levels, this.ink);
  final List<double> levels;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final n = (size.width / 6).floor();
    for (var i = 0; i < n; i++) {
      final index = levels.length - n + i;
      final value = index < 0 ? 0.0 : levels[index];
      final height = math.max(2.0, value * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 6, (size.height - height) / 2, 3, height),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = ink.withValues(
            alpha: index < 0 ? .18 : .35 + .65 * i / math.max(1, n - 1),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter old) => true;
}

class _SendRing extends CustomPainter {
  _SendRing(this.progress, this.ink);
  final double progress;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: 25),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SendRing old) =>
      old.progress != progress || old.ink != ink;
}
