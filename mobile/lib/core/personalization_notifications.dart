import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'inventory_context.dart';
import 'inventory_cache.dart';
import '../features/inventory/item_detail_sheet.dart';
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
            payload['action'] == 'personalization' &&
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
    if (id == null || !{'delivered', 'opened', 'dismissed'}.contains(outcome)) {
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
    try {
      final data = await ApiClient.forAccount(
        api,
        account!,
      ).collaboration('/personalization/notifications/$id/destination');
      if (!context.mounted || api.accountId != account) return;
      if (data['notification_id'] != id ||
          !{'item', 'review'}.contains(data['entity_type'])) {
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
      final resource = Map<String, dynamic>.from(data['resource'] as Map);
      final resourceId =
          resource[data['entity_type'] == 'item' ? 'item_id' : 'review_id'];
      if (resourceId != data['entity_id']) {
        throw const FormatException('This notification target changed.');
      }
      unawaited(feedback(api, payload, 'opened'));
      if (data['entity_type'] == 'item') {
        final item = InventoryItem.fromJson(resource);
        await showItemDetailSheet(
          context,
          item: item,
          api: scoped,
          spaceName: item.location,
          permission: scoped.canEdit ? 'edit' : 'view',
          onItemUpdated: (item) =>
              InventoryCache.updateItem(item, contextKey: scoped.cacheKey),
        );
      } else {
        if (resource['status'] != 'pending') {
          throw const FormatException('This review is already complete.');
        }
        await showReviewDetail(
          context,
          api: scoped,
          item: ReviewItem.fromJson(resource),
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
  }
}
