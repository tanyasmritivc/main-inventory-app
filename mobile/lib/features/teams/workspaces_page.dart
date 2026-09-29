import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/world_views.dart';
import 'workspace_detail_page.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({
    super.key,
    required this.api,
    required this.currentWorkspaceId,
    required this.onSelect,
  });

  final ApiClient api;
  final String? currentWorkspaceId;
  final Future<void> Function(Map<String, dynamic>) onSelect;

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  List<Map<String, dynamic>>? _workspaces;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final workspaces = await widget.api.listWorkspaces();
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Workspace name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final workspace = await widget.api.createWorkspace(name);
      await _load();
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => WorkspaceDetailPage(
            api: widget.api,
            workspaceId: workspace['workspace_id'].toString(),
            isCurrent: false,
            onSelect: widget.onSelect,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open(Map<String, dynamic> workspace) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceDetailPage(
          api: widget.api,
          workspaceId: workspace['workspace_id'].toString(),
          isCurrent: workspace['workspace_id'] == widget.currentWorkspaceId,
          onSelect: widget.onSelect,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final workspaces = _workspaces;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Workspaces',
              onBack: () => Navigator.pop(context),
              actions: [
                TextButton(
                  onPressed: _creating ? null : _create,
                  child: Text(_creating ? 'Creating' : 'New'),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    Text(
                      'Choose which collection of objects and conversations you are working in.',
                      style: TextStyle(color: t.text2, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    if (workspaces == null && _error == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load workspaces',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else if (workspaces!.isEmpty)
                      WorldSection(
                        title: 'Your workspaces',
                        children: [
                          const WorldRow(title: 'No workspaces yet', count: ''),
                          WorldRow(
                            title: 'Create a workspace',
                            count: '',
                            onTap: _create,
                          ),
                        ],
                      )
                    else
                      WorldSection(
                        title: 'Your workspaces',
                        children: [
                          for (final workspace in workspaces)
                            WorldRow(
                              title: (workspace['name'] ?? 'Workspace')
                                  .toString(),
                              subtitle:
                                  workspace['workspace_id'] ==
                                      widget.currentWorkspaceId
                                  ? 'Current workspace'
                                  : (workspace['kind'] ?? '').toString(),
                              count:
                                  workspace['workspace_id'] ==
                                      widget.currentWorkspaceId
                                  ? 'HERE'
                                  : '',
                              onTap: () => _open(workspace),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
