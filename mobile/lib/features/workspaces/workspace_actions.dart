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
}) => _confirmDeletion(
  context,
  api,
  id: id,
  name: name,
  kind: 'workspace',
  path: '/teams/${Uri.encodeComponent(id)}',
  explanation:
      'This removes collaboration, tasks and workspace files. Physical inventories are retained for their owners in Personal. This cannot be undone.',
);

Future<bool> confirmOrganizationDeletion(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
}) => _confirmDeletion(
  context,
  api,
  id: id,
  name: name,
  kind: 'organization',
  path: '/organizations/${Uri.encodeComponent(id)}',
  explanation:
      'Delete this empty organization. Remove its workspaces first; deleting a workspace keeps its inventories in Personal. This cannot be undone.',
);

Future<bool> _confirmDeletion(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
  required String kind,
  required String path,
  required String explanation,
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
              title: Text('Delete $kind'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(explanation),
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
                        style: TextStyle(
                          color: PlacePalette.of(context).destructive,
                        ),
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
                    foregroundColor: PlacePalette.of(context).destructive,
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
                              path,
                              method: 'DELETE',
                              data: kind == 'organization'
                                  ? {'name': entered}
                                  : null,
                            );
                            if (result['deleted'] != true ||
                                (kind == 'organization' &&
                                    result['organization_id'] != id)) {
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
                  child: Text(busy ? 'Deleting...' : 'Delete $kind'),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
