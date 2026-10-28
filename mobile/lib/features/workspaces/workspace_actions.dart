import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/api_error.dart';
import 'place_ui.dart';

/// Reuses owner-authorized workspace removal and preserves physical inventories.
Future<bool> confirmWorkspaceDeletion(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
}) async {
  var entered = '';
  var busy = false;
  String? error;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: const Text('Delete workspace'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This removes collaboration, tasks and workspace files. Physical inventories are retained for their owners in Personal. This cannot be undone.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      autofocus: true,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'Type $name to confirm',
                      ),
                      onChanged: (value) => update(() => entered = value),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: PlaceTokens.destructive),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialog, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: PlaceTokens.destructive,
                  ),
                  onPressed: busy || entered != name
                      ? null
                      : () async {
                          update(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final result = await api.collaboration(
                              '/teams/${Uri.encodeComponent(id)}',
                              method: 'DELETE',
                            );
                            if (result['deleted'] != true) {
                              throw const FormatException(
                                'Deletion could not be confirmed. Refresh before retrying.',
                              );
                            }
                            InventoryCache.clear();
                            if (dialog.mounted) {
                              Navigator.pop(dialog, true);
                            }
                          } catch (reason) {
                            if (dialog.mounted) {
                              update(() {
                                busy = false;
                                error = describeError(reason).$1;
                              });
                            }
                          }
                        },
                  child: Text(busy ? 'Deleting...' : 'Delete workspace'),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
