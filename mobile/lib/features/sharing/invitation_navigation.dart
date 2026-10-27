import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/invitation_destination.dart';
import 'shared_inventory_page.dart';

void openInvitationResult(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic>? result,
) {
  final owner = api.accountId;
  if (owner == null || result?['accepted'] != true) return;
  final share = result!['share_id'];
  if (share is String && share.isNotEmpty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedInventoryPage(
          api: api,
          shareId: share,
          shareName: (result['share_name'] ?? result['name'] ?? 'Shared Space')
              .toString(),
          permission: result['permission']?.toString() ?? 'view',
        ),
      ),
    );
    return;
  }
  final workspace = result['workspace_id'] ?? result['team_id'];
  final organization = result['organization_id'];
  if ((workspace is! String || workspace.isEmpty) &&
      (organization is! String || organization.isEmpty)) {
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
  InvitationNavigation.instance.open(
    owner,
    InvitationDestination(
      organizationId: organization as String?,
      workspaceId: workspace as String?,
      inventoryId: result['inventory_id'] as String?,
    ),
  );
}
