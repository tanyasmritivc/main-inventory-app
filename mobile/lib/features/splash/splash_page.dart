import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.onFinished, this.duration});

  final VoidCallback? onFinished;
  final Duration? duration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _t = Timer(widget.duration ?? const Duration(milliseconds: 1050), () {
      if (!mounted) return;
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.black,
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.9,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 28,
                                  sigmaY: 28,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF60A5FA)
                                            .withValues(alpha: 0.26),
                                        const Color(0xFFC084FC)
                                            .withValues(alpha: 0.14),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.55, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FindEZ AI',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Organize everything instantly',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    height: 1.25,
                                  ),
                            ),
                          ],
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
    );
  }
}
