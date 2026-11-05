import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';

Future<bool> confirmOrganizationLeave(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
  required bool isOwner,
}) async {
  final account = api.accountId;
  var busy = false;
  String? error;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: AppText('Leave $name?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      isOwner
                          ? 'Transfer organization ownership to another member before leaving.'
                          : "You will lose access to this organization and its workspaces, inventories and Spaces. The team's items, photos, tasks and files will stay. You will need an invitation to rejoin.",
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      AppText(
                        error!,
                        style: TextStyle(
                          color: Theme.of(dialog).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialog, false),
                  child: AppText(isOwner ? 'Close' : 'Cancel'),
                ),
                if (!isOwner)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            update(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              if (api.accountId != account) {
                                throw const FormatException(
                                  'Your account changed. Reopen this page.',
                                );
                              }
                              final result = await api.collaboration(
                                '/organizations/${Uri.encodeComponent(id)}/leave',
                                method: 'DELETE',
                                data: {'name': name},
                              );
                              if (api.accountId != account) {
                                throw const FormatException(
                                  'Your account changed. Reopen this page.',
                                );
                              }
                              if (result['left'] != true ||
                                  result['organization_id'] != id) {
                                throw const FormatException(
                                  'Leaving could not be confirmed. Refresh before retrying.',
                                );
                              }
                              InventoryCache.clear();
                              if (dialog.mounted) Navigator.pop(dialog, true);
                            } catch (reason) {
                              if (dialog.mounted) {
                                update(() {
                                  busy = false;
                                  error = describeError(reason).$1;
                                });
                              }
                            }
                          },
                    child: AppText(busy ? 'Leaving...' : 'Leave organization'),
                  ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
