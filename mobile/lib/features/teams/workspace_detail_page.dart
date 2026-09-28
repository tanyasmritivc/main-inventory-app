import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/world_views.dart';

class WorkspaceDetailPage extends StatefulWidget {
  const WorkspaceDetailPage({
    super.key,
    required this.api,
    required this.workspaceId,
    required this.isCurrent,
    this.onSelect,
  });

  final ApiClient api;
  final String workspaceId;
  final bool isCurrent;
  final Future<void> Function(Map<String, dynamic>)? onSelect;

  @override
  State<WorkspaceDetailPage> createState() => _WorkspaceDetailPageState();
}

class _WorkspaceDetailPageState extends State<WorkspaceDetailPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getWorkspaceDetail(widget.workspaceId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _select(Map<String, dynamic> workspace) async {
    if (widget.onSelect == null || _switching) return;
    setState(() => _switching = true);
    try {
      await widget.onSelect!(workspace);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final data = _data;
    final workspace = data?['workspace'] is Map
        ? Map<String, dynamic>.from(data!['workspace'] as Map)
        : const <String, dynamic>{};
    final members = data?['members'] is List
        ? List<Map<String, dynamic>>.from(data!['members'] as List)
        : const <Map<String, dynamic>>[];
    final places = data?['places'] is List
        ? List<Map<String, dynamic>>.from(data!['places'] as List)
        : const <Map<String, dynamic>>[];
    final name = (workspace['name'] ?? 'Workspace').toString();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(title: name, onBack: () => Navigator.pop(context)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (data == null && _error == null)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Loading workspace',
                              style: TextStyle(color: t.text2),
                            ),
                          ],
                        ),
                      )
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load workspace',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else ...[
                      Text(
                        '${members.length} people  ·  ${workspace['object_count']} objects',
                        style: TextStyle(
                          color: t.text2,
                          fontSize: 13,
                          fontFamily: 'IBMPlexMono',
                        ),
                      ),
                      const SizedBox(height: 18),
                      WorldSection(
                        title: 'People',
                        children: [
                          if (members.isEmpty)
                            const WorldRow(title: 'No people found', count: ''),
                          for (final member in members)
                            WorldRow(
                              title: (member['display_name'] ?? 'Member')
                                  .toString(),
                              subtitle:
                                  member['user_id'] ==
                                      workspace['owner_user_id']
                                  ? 'Workspace owner'
                                  : null,
                              count: (member['role'] ?? '')
                                  .toString()
                                  .toUpperCase(),
                            ),
                        ],
                      ),
                      WorldSection(
                        title: 'Places',
                        children: [
                          if (places.isEmpty)
                            const WorldRow(title: 'No places yet', count: ''),
                          for (final place in places)
                            WorldRow(
                              title: (place['name'] ?? '').toString(),
                              count: (place['object_count'] ?? '').toString(),
                            ),
                        ],
                      ),
                      WorldSection(
                        title: 'Your access',
                        children: [
                          WorldRow(
                            title: 'Role',
                            count: '',
                            subtitle: (workspace['role'] ?? '').toString(),
                          ),
                          WorldRow(
                            title: 'Workspace type',
                            count: '',
                            subtitle: (workspace['kind'] ?? '').toString(),
                          ),
                        ],
                      ),
                      if (!widget.isCurrent && widget.onSelect != null) ...[
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _switching
                              ? null
                              : () => _select(workspace),
                          child: Text(
                            _switching ? 'Switching' : 'Use this workspace',
                          ),
                        ),
                      ],
                    ],
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
