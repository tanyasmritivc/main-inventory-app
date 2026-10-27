import 'package:flutter/foundation.dart';

/// A confirmed invitation receipt identifies a destination, never grants access.
/// The directory and inventory clients revalidate its parents before opening it.
class InvitationDestination {
  const InvitationDestination({
    this.organizationId,
    this.workspaceId,
    this.inventoryId,
  });
  final String? organizationId, workspaceId, inventoryId;

  static String? _id(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  factory InvitationDestination.fromAccess(Map<String, dynamic> row) {
    final resource = _id(row['resource_id']);
    final organization = _id(row['organization_id']);
    final workspace = _id(row['team_id']);
    final inventory = _id(row['inventory_id']);
    if (row['status'] != 'accepted' || resource == null) {
      throw const FormatException(
        'Invitation acceptance could not be confirmed. Retry the review.',
      );
    }
    switch (row['scope']) {
      case 'organization':
        if (organization != null && organization != resource) break;
        return InvitationDestination(organizationId: resource);
      case 'workspace':
        if (workspace != null && workspace != resource) break;
        return InvitationDestination(
          organizationId: organization,
          workspaceId: resource,
        );
      case 'inventory':
        if (workspace == null || (inventory != null && inventory != resource)) {
          break;
        }
        return InvitationDestination(
          organizationId: organization,
          workspaceId: workspace,
          inventoryId: resource,
        );
    }
    throw const FormatException(
      'This invitation destination changed. Refresh the review.',
    );
  }

  Map<String, dynamic> toResult() => {
    'accepted': true,
    if (organizationId != null) 'organization_id': organizationId,
    if (workspaceId != null) 'workspace_id': workspaceId,
    if (inventoryId != null) 'inventory_id': inventoryId,
  };
}

/// The authenticated root consumes a handoff instead of stacking another shell.
/// Keeping it pending also covers a link accepted while setup is still loading.
class InvitationNavigation extends ChangeNotifier {
  static final instance = InvitationNavigation();
  String? _owner;
  InvitationDestination? _pending;
  void open(String owner, InvitationDestination destination) {
    _owner = owner;
    _pending = destination;
    notifyListeners();
  }

  InvitationDestination? take(String owner) {
    if (_owner != owner) return null;
    final target = _pending;
    _owner = null;
    _pending = null;
    return target;
  }
}
