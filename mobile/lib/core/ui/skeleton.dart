import 'package:flutter/material.dart';

/// One diagonal light sweep shared by all blocks in a loading region.
class SkeletonShine extends StatefulWidget {
  const SkeletonShine({super.key, required this.child});
  final Widget child;
  @override
  State<SkeletonShine> createState() => _SkeletonShineState();
}

class _SkeletonShineState extends State<SkeletonShine>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
      _motion.value = .5;
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-3 + _motion.value * 6, -1),
          end: Alignment(-1 + _motion.value * 6, 1),
          colors: const [
            Colors.transparent,
            Color(0x40FFFFFF),
            Colors.transparent,
          ],
          stops: const [.2, .5, .8],
        ).createShader(rect),
        child: child,
      ),
    ),
  );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 14,
  });
  final double height;
  final double? width;
  final double borderRadius;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252525)
            : const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});
  @override
  Widget build(BuildContext context) => SkeletonShine(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Row(
        children: [
          const SkeletonBox(height: 52, width: 52, borderRadius: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                FractionallySizedBox(
                  widthFactor: .65,
                  child: SkeletonBox(height: 14),
                ),
                SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: .9,
                  child: SkeletonBox(height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading page',
    child: ExcludeSemantics(
      child: SkeletonShine(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(height: 24, width: 160),
            ),
            const SizedBox(height: 28),
            const SkeletonBox(height: 72, borderRadius: 24),
            const SizedBox(height: 24),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: const [
                    SkeletonBox(height: 56, width: 56, borderRadius: 18),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: .6,
                            child: SkeletonBox(height: 14),
                          ),
                          SizedBox(height: 12),
                          FractionallySizedBox(
                            widthFactor: .85,
                            child: SkeletonBox(height: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
