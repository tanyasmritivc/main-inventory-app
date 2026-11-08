import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/api_client.dart';
import '../../core/ui/liquid_surface.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import 'chat_page.dart';

/// A contextual assistant always receives the already-authorized inventory client.
/// It cannot silently fall back to the organization-wide chat or legacy account.
class InventoryChatButton extends StatelessWidget {
  const InventoryChatButton({
    super.key,
    required this.api,
    this.primary,
    this.prominent = false,
    this.spaceId,
    this.spaceName,
  });
  final ApiClient api;
  final Widget? primary;
  final bool prominent;
  final String? spaceId, spaceName;

  Future<void> _open(BuildContext context) async {
    if (api.inventoryContext == null) return;
    try {
      api.assertCurrentContext();
      var chatApi = api;
      if (spaceName != null) {
        var id = spaceId;
        if (id == null) {
          final matches = (await api.listSpaces())
              .where((s) => s['name'] == spaceName)
              .toList();
          if (matches.length != 1) {
            throw const AskRequestException(
              'This Space is no longer available. Refresh your Spaces.',
            );
          }
          id = (matches.single['id'] ?? matches.single['space_id'])?.toString();
        }
        if (id == null || id.isEmpty) {
          throw const AskRequestException('Choose an available Space.');
        }
        api.assertCurrentContext();
        chatApi = ApiClient.forSpaceChat(api, id, spaceName!);
      }
      if (!context.mounted) return;
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        await showCupertinoSheet<void>(
          context: context,
          useNestedNavigation: true,
          showDragHandle: true,
          // Keep compatibility with the release SDK, which lacks scrollableBuilder.
          // ignore: deprecated_member_use
          builder: (context) => _InventoryChatSheet(api: chatApi),
        );
        return;
      }
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
                                  child: Text(
                                    'Only in ${chatApi.chatSpaceName ?? api.inventoryContext!.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                              api: chatApi,
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
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B1B1B)
              : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppTheme.isDark(context)
                ? colors.onSurface.withValues(alpha: .06)
                : AppTheme.controlBorder(context),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: .55),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ask FindEZ',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: .65),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
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

/// Cupertino owns sheet motion, corner geometry, safe areas and drag dismissal.
/// The same scoped ChatPage retains streaming, attachments and cancellation.
class _InventoryChatSheet extends StatelessWidget {
  const _InventoryChatSheet({required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.light
        ? AppTheme.lightBg
        : CupertinoColors.systemGroupedBackground.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: surface,
        border: null,
        automaticallyImplyLeading: false,
        middle: Text(
          'Only in ${api.chatSpaceName ?? api.inventoryContext!.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        trailing: Tooltip(
          message: 'Close contextual chat',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => CupertinoSheetRoute.popSheet(context),
            child: Icon(
              CupertinoIcons.xmark,
              size: 20,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              semanticLabel: 'Close contextual chat',
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ChatPage(api: api, contextual: true, inPageView: true),
      ),
    );
  }
}
