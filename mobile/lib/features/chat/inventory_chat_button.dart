import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/ui/liquid_surface.dart';
import '../../core/api_error.dart';
import 'chat_page.dart';

/// A contextual assistant always receives the already-authorized inventory client.
/// It cannot silently fall back to the organization-wide chat or legacy account.
class InventoryChatButton extends StatelessWidget {
  const InventoryChatButton({
    super.key,
    required this.api,
    this.primary,
    this.prominent = false,
  });
  final ApiClient api;
  final Widget? primary;
  final bool prominent;

  Future<void> _open(BuildContext context) async {
    if (api.inventoryContext == null) return;
    try {
      api.assertCurrentContext();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .16),
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height:
                  (constraints.maxHeight -
                          MediaQuery.viewInsetsOf(context).bottom)
                      .clamp(0.0, constraints.maxHeight) *
                  (MediaQuery.viewInsetsOf(context).bottom > 0 ? 1 : .86),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: .92),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ask FindEZ',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Only in ${api.inventoryContext!.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close contextual chat',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ChatPage(
                              api: api,
                              contextual: true,
                              inPageView: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (api.inventoryContext == null) return primary ?? const SizedBox.shrink();
    if (prominent) {
      final colors = Theme.of(context).colorScheme;
      return LiquidSurface(
        radius: 18,
        shadow: false,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ask FindEZ',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: colors.onSurface,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LiquidSurface(
          radius: 28,
          shadow: false,
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    SizedBox(width: 9),
                    Text('Ask FindEZ'),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (primary != null) ...[const SizedBox(height: 12), primary!],
      ],
    );
  }
}
