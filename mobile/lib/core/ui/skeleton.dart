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

enum SkeletonLayout {
  list,
  spaces,
  items,
  history,
  documents,
  board,
  form,
  chat,
}

/// Data placeholders match the pending content, never the navigation animation.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({
    super.key,
    this.layout = SkeletonLayout.list,
    this.padding = const EdgeInsets.all(20),
  });
  final SkeletonLayout layout;
  final EdgeInsets padding;

  Widget _lines({double width = .65}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FractionallySizedBox(
          widthFactor: width,
          child: const SkeletonBox(height: 16),
        ),
        const SizedBox(height: 12),
        const FractionallySizedBox(
          widthFactor: .45,
          child: SkeletonBox(height: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading ${layout == SkeletonLayout.list ? 'content' : layout.name}',
    child: ExcludeSemantics(
      child: SkeletonShine(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          children: [
            if (layout == SkeletonLayout.chat) ...[
              const SizedBox(height: 120),
              const Center(child: SkeletonBox(height: 24, width: 240)),
              const SizedBox(height: 28),
              const SkeletonBox(height: 128, borderRadius: 24),
            ] else
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: layout == SkeletonLayout.spaces ? 32 : 20,
                  ),
                  child: switch (layout) {
                    SkeletonLayout.board => const SkeletonBox(
                      height: 120,
                      borderRadius: 24,
                    ),
                    SkeletonLayout.form => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 12, width: 100),
                        SizedBox(height: 12),
                        SkeletonBox(height: 52),
                      ],
                    ),
                    SkeletonLayout.history => Row(
                      children: [_lines(width: i.isEven ? .75 : .55)],
                    ),
                    _ => Row(
                      children: [
                        SkeletonBox(
                          height: layout == SkeletonLayout.spaces ? 64 : 48,
                          width: layout == SkeletonLayout.spaces ? 64 : 48,
                          borderRadius: layout == SkeletonLayout.documents
                              ? 8
                              : 16,
                        ),
                        const SizedBox(width: 16),
                        _lines(),
                        if (layout == SkeletonLayout.items) ...[
                          const SizedBox(width: 12),
                          const SkeletonBox(
                            height: 24,
                            width: 32,
                            borderRadius: 8,
                          ),
                        ],
                      ],
                    ),
                  },
                ),
          ],
        ),
      ),
    ),
  );
}
