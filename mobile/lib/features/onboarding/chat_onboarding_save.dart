import '../../core/api_client.dart';
import '../../core/first_camera_hint.dart';
import '../../core/inventory_context.dart';
import 'chat_onboarding_draft.dart';

/// Uses exactly the Confirm Items write contract, including its replay receipts.
class ChatOnboardingSaver {
  ChatOnboardingSaver(this.source);
  final ApiClient source;
  Future<void> save(ChatOnboardingDraft draft) async {
    final account = source.accountId;
    if (account == null || (draft.owner != null && draft.owner != account)) {
      throw StateError('Sign in to the account that started this save.');
    }
    if (draft.isSample) {
      draft.owner = account;
      await FirstCameraHint.arm(account);
      draft.complete = true;
      await ChatOnboardingStore.save(draft);
      return; // Demo items must never reach an inventory API, even on retry.
    }
    if (draft.items.isEmpty) throw StateError('There are no items to save.');
    draft.owner = account;
    draft.saving = true;
    await ChatOnboardingStore.save(draft);
    final api = ApiClient.forAccount(source, account);
    if (draft.inventoryId == null) {
      final inventories = <Map<String, dynamic>>[];
      int? offset = 0;
      do {
        final data = await api.collaboration(
          '/inventory-workspaces/personal/inventories',
          query: {'offset': offset},
        );
        inventories.addAll(
          (data['inventories'] as List).map(
            (r) => Map<String, dynamic>.from(r),
          ),
        );
        final next = data['next_offset'] as int?;
        if (next != null && next <= offset!) {
          throw const FormatException('Refresh your inventories.');
        }
        offset = next;
      } while (offset != null);
      if (inventories.isEmpty) {
        // The existing API enforces unique names. On an uncertain response the
        // next run lists first, reconciling a successful creation before retry.
        final result = await api.collaboration(
          '/inventory-workspaces/personal/inventories',
          method: 'POST',
          data: {'name': 'My Personal Inventory'},
        );
        draft.inventoryId =
            (result['inventory'] as Map)['inventory_id'] as String;
      } else {
        final selected = inventories.firstWhere(
          (i) => i['is_default'] == true,
          orElse: () => inventories.first,
        );
        draft.inventoryId = selected['inventory_id'] as String;
      }
      api.assertCurrentContext();
      await ChatOnboardingStore.save(draft);
    }
    final result = await api.collaboration('/inventories/${draft.inventoryId}');
    final context = InventoryContext.fromJson(
      Map<String, dynamic>.from(result['inventory']),
      accountId: account,
      expectedInventory: draft.inventoryId!,
      expectedWorkspace: 'personal',
    );
    if (!context.canEdit) throw StateError('This inventory is read-only.');
    final scoped = ApiClient.forInventory(
      source,
      context,
      isCurrent: () => source.accountId == account,
    );
    // createSpace is the existing get-or-create API; repeated calls reuse it.
    final space = await scoped.createSpace(name: draft.space);
    draft.spaceId = (space['id'] ?? space['space_id']) as String;
    await ChatOnboardingStore.save(draft);
    final items = draft.items
        .map(
          (trial) => ExtractedInventoryItem.fromJson({
            ...trial.item.toJson(),
            'location': draft.space,
            // Retained drafts from earlier builds can have no category.
            'category': trial.item.category.trim().isEmpty
                ? 'Other'
                : trial.item.category,
          }),
        )
        .toList();
    // The extraction model has no sub-location field. Keep spots in the local
    // trial; don't overwrite the real Space or fabricate another field.
    final receipt = await scoped.bulkCreateInventory(
      items: items,
      requestIds: List.generate(
        items.length,
        (i) => 'onboarding-${draft.id}-$i',
      ),
    );
    if (receipt.confirmedIndices(items.length).length != items.length) {
      throw StateError(
        'Some items could not be confirmed saved. Retry safely.',
      );
    }
    scoped.assertCurrentContext();
    draft.complete = true;
    await ChatOnboardingStore.save(draft);
    // Retain the completion receipt until the Ask handoff acknowledges it.
  }
}
