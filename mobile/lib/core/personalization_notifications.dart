import 'package:mobile/core/notification_visit.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'inventory_context.dart';
import 'inventory_cache.dart';
import '../features/inventory/item_detail_sheet.dart';
import '../features/inventory/inventory_page.dart';
import '../features/scan/scan_page.dart';
import '../features/review/review_queue_page.dart';

/// Payloads identify a server-owned notification; they never authorize a resource.
class PersonalizationNotifications {
  static final _opening = <String>{};
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String? identifier(Map<String, dynamic> payload, String? account) {
    final id = payload['notification_id'];
    return account != null &&
            {
              'personalization',
              'daily_inventory',
            }.contains(payload['action']) &&
            payload['recipient_user_id'] == account &&
            id is String &&
            _uuid.hasMatch(id)
        ? id
        : null;
  }

  static Future<void> feedback(
    ApiClient api,
    Map<String, dynamic> payload,
    String outcome,
  ) async {
    final account = api.accountId;
    final id = identifier(payload, account);
    if (id == null ||
        !{
          'delivered',
          'opened',
          'dismissed',
          'push_tapped',
          'destination_opened',
          'action_started',
          'record_reviewed',
          'scan_saved',
        }.contains(outcome)) {
      return;
    }
    try {
      await ApiClient.forAccount(api, account!)
          .collaboration(
            '/personalization/notifications/$id/feedback',
            method: 'POST',
            data: {'outcome': outcome},
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Optional telemetry never blocks navigation and is never treated as completion.
    }
  }

  static Future<void> open(
    BuildContext context,
    ApiClient api,
    Map<String, dynamic> payload,
  ) async {
    final account = api.accountId;
    final id = identifier(payload, account);
    if (id == null) return;
    final key = '$account:$id';
    if (!_opening.add(key)) return;
    var nextRecord = false;
    try {
      final data = await ApiClient.forAccount(
        api,
        account!,
      ).collaboration('/personalization/notifications/$id/destination');
      if (!context.mounted || api.accountId != account) return;
      if (data['notification_id'] != id ||
          !{'item', 'review', 'inventory'}.contains(data['entity_type'])) {
        throw const FormatException(
          'This notification is no longer available.',
        );
      }
      final inventory = InventoryContext.fromJson(
        Map<String, dynamic>.from(data['inventory'] as Map),
        accountId: account,
        expectedInventory: data['inventory_id'] as String,
      );
      final scoped = ApiClient.forInventory(
        api,
        inventory,
        isCurrent: () => context.mounted && api.accountId == account,
      );
      final action = data['quick_action'];
      final visit = NotificationVisit(
        (event) => feedback(api, payload, event),
        canMarkReviewed: {
          'low_stock',
          'expiry',
          'progress',
          'rediscover',
        }.contains(action),
      );
      if (data['entity_type'] == 'inventory') {
        final action = data['quick_action'];
        if (data['entity_id'] != data['inventory_id'] ||
            data['active'] != true ||
            !scoped.canEdit ||
            !{'first_item', 'add_item', 'snap'}.contains(action)) {
          throw const FormatException(
            'This inventory reminder is no longer available.',
          );
        }

        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => action == 'snap'
                ? ScanPage(
                    api: scoped,
                    isActive: true,
                    onSaved: () {},
                    visit: visit,
                  )
                : InventoryPage(
                    api: scoped,
                    refreshToken: 0,
                    openAddItem: true,
                    visit: visit,
                  ),
          ),
        );
        return;
      }
      final resource = Map<String, dynamic>.from(data['resource'] as Map);
      final resourceId =
          resource[data['entity_type'] == 'item' ? 'item_id' : 'review_id'];
      if (resourceId != data['entity_id']) {
        throw const FormatException('This notification target changed.');
      }

      if (data['entity_type'] == 'item') {
        final item = InventoryItem.fromJson(resource);
        var changed = false;
        await showItemDetailSheet(
          context,
          item: item,
          visit: visit,
          api: scoped,
          spaceName: item.location,
          permission: scoped.canEdit ? 'edit' : 'view',
          onItemUpdated: (updated) {
            changed =
                changed ||
                (action == 'discovery' && updated.location.trim().isNotEmpty) ||
                (action == 'weekly_insight' && updated.quantity >= 0);
            InventoryCache.updateItem(updated, contextKey: scoped.cacheKey);
          },
        );
        if (changed &&
            (data['remaining_ids'] as List? ?? []).length > 1 &&
            context.mounted &&
            api.accountId == account) {
          nextRecord =
              await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Review another record?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Done'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Next record'),
                    ),
                  ],
                ),
              ) ??
              false;
        }
      } else {
        if (resource['status'] != 'pending') {
          throw const FormatException('This review is already complete.');
        }
        await showReviewDetail(
          context,
          api: scoped,
          item: ReviewItem.fromJson(resource),
          visit: visit,
        );
      }
    } catch (error) {
      if (context.mounted && api.accountId == account) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      _opening.remove(key);
    }
    if (nextRecord && context.mounted && api.accountId == account) {
      await open(context, api, payload);
    }
  }
}
