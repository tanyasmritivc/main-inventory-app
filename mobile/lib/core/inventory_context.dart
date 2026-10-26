/// A server-authorized collection. IDs are navigation context, never grants.
class InventoryContext {
  const InventoryContext({
    required this.accountId,
    required this.inventoryId,
    required this.name,
    required this.workspaceId,
    required this.workspaceName,
    required this.role,
    required this.canEdit,
    required this.canManage,
    required this.canRename,
    this.organizationId,
    this.organizationName,
  });

  final String accountId, inventoryId, name, workspaceId, workspaceName, role;
  final String? organizationId, organizationName;
  final bool canEdit, canManage, canRename;
  bool get isPersonal => workspaceId == 'personal';
  String get label => '$workspaceName / $name';

  factory InventoryContext.fromJson(
    Map<String, dynamic> json, {
    required String accountId,
    required String expectedInventory,
    String? expectedWorkspace,
  }) {
    final workspace = Map<String, dynamic>.from(
      json['workspace'] as Map? ?? {},
    );
    final id = json['inventory_id']?.toString() ?? '';
    final workspaceId = workspace['workspace_id']?.toString() ?? '';
    if (id != expectedInventory ||
        workspaceId.isEmpty ||
        (expectedWorkspace != null && workspaceId != expectedWorkspace) ||
        (json['team_id']?.toString() ?? 'personal') != workspaceId) {
      throw const FormatException(
        'The inventory context changed. Refresh and choose again.',
      );
    }
    return InventoryContext(
      accountId: accountId,
      inventoryId: id,
      name: json['name'] as String,
      workspaceId: workspaceId,
      workspaceName: workspace['name'] as String,
      organizationId: workspace['organization_id'] as String?,
      organizationName: workspace['organization_name'] as String?,
      role: json['role'] as String,
      canEdit: json['can_edit'] == true,
      canManage: json['can_manage'] == true,
      canRename: json['can_rename'] == true,
    );
  }
}

String membershipRoleLabel(String role) => switch (role) {
  'mentor' => 'Admin',
  'member' => 'Editor',
  'none' => 'No access',
  'inherit' => 'Use workspace role',
  _ =>
    role.isEmpty ? 'Unknown' : '${role[0].toUpperCase()}${role.substring(1)}',
};

String physicalLocationPath(
  Map<String, dynamic> location,
  List<Map<String, dynamic>> locations,
) {
  final names = [location['name'].toString()];
  final seen = {location['location_id']};
  var parent = location['parent_id'];
  while (parent != null && seen.add(parent)) {
    final matches = locations.where((row) => row['location_id'] == parent);
    if (matches.isEmpty) break;
    final row = matches.first;
    names.insert(0, row['name'].toString());
    parent = row['parent_id'];
  }
  return names.join(' / ');
}
