import 'package:flutter/material.dart';

import '../app_theme.dart';

class SkeletonBox extends StatefulWidget {
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
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tokens = AppTokens.of(context);
        final v = _controller.value;

        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(tokens.raised, tokens.line, v),
          ),
        );
      },
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          const SkeletonBox(height: 42, width: 42, borderRadius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14, width: 160, borderRadius: 10),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 220, borderRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(height: 12, width: 44, borderRadius: 10),
        ],
      ),
    );
  }
}
