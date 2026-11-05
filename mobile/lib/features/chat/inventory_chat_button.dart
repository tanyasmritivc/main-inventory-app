import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/ui/liquid_surface.dart';
import '../world/world_style.dart';
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
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .16),
        builder: (context) => WorldStyle(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: .92,
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: ChatPage(
                  api: api,
                  contextual: true,
                  inPageView: true,
                  worldHeading: 'Ask about ${api.inventoryContext!.name}',
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
        ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
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
                    child: AppText(
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
                    AppText('Ask FindEZ'),
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
