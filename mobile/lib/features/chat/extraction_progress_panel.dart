import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'chat_progress.dart';

/// Quiet placeholders while the existing extraction stream reports real stages.
class ExtractionProgressPanel extends StatelessWidget {
  const ExtractionProgressPanel({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget bar(double width) => Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CupertinoActivityIndicator(
                animating: !reduced,
                radius: 9,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(child: ChatProgress(message: message)),
            ],
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Column(
              children: [
                for (var index = 0; index < 2; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (_, constraints) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bar(
                                  constraints.maxWidth *
                                      (index == 0 ? .72 : .56),
                                ),
                                const SizedBox(height: 8),
                                bar(constraints.maxWidth * .36),
                              ],
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
      ),
    );
  }
}
