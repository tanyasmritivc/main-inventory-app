import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';
import '../../core/upgrade_sheet.dart';

class TeamBoardPage extends StatefulWidget {
  const TeamBoardPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<TeamBoardPage> createState() => _TeamBoardPageState();
}

class _TeamBoardPageState extends State<TeamBoardPage> {
  List<Map<String, dynamic>> _teams = const [];
  List<Map<String, dynamic>> _tasks = const [];
  Map<String, dynamic>? _team;
  String _role = 'viewer';
  bool _loading = true;
  String? _error;

  bool get _canEdit => _role != 'viewer';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({String? teamId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await widget.api.listTeams();
      Map<String, dynamic>? selected;
      if (teams.isNotEmpty) {
        selected = teams.firstWhere(
          (team) => team['team_id'].toString() == teamId,
          orElse: () => _team == null
              ? teams.first
              : teams.firstWhere(
                  (team) => team['team_id'] == _team?['team_id'],
                  orElse: () => teams.first,
                ),
        );
      }
      var tasks = <Map<String, dynamic>>[];
      var role = 'viewer';
      if (selected != null) {
        final board = await widget.api.getTeamBoard(selected['team_id'].toString());
        tasks = List<Map<String, dynamic>>.from(board['tasks'] ?? const []);
        role = board['role']?.toString() ?? 'viewer';
      }
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _team = selected;
        _tasks = tasks;
        _role = role;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error).$1;
        _loading = false;
      });
    }
  }

  Future<void> _chooseTeam() async {
    if (_teams.length < 2) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Choose team')),
            for (final team in _teams)
              ListTile(
                title: Text(team['name']?.toString() ?? 'Team'),
                subtitle: Text((team['program']?.toString() ?? '').toUpperCase()),
                trailing: team['team_id'] == _team?['team_id']
                    ? const Icon(CupertinoIcons.check_mark)
                    : null,
                onTap: () => Navigator.pop(context, team['team_id'].toString()),
              ),
          ],
        ),
      ),
    );
    if (id != null) await _load(teamId: id);
  }

  Future<void> _createTeam() async {
    final name = TextEditingController();
    var program = 'ftc';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create a team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Your Team Board is created automatically.', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Team name or number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: program,
                  decoration: const InputDecoration(labelText: 'Program'),
                  items: const [
                    DropdownMenuItem(value: 'ftc', child: Text('FIRST Tech Challenge')),
                    DropdownMenuItem(value: 'frc', child: Text('FIRST Robotics Competition')),
                    DropdownMenuItem(value: 'fll', child: Text('FIRST LEGO League')),
                    DropdownMenuItem(value: 'vex', child: Text('VEX Robotics')),
                  ],
                  onChanged: (value) => setSheetState(() => program = value ?? 'ftc'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Create Team Board'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    try {
      final team = await widget.api.createTeam(name: name.text.trim(), program: program);
      await _load(teamId: team['team_id']?.toString());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _copyJoinCode() async {
    final code = _team?['join_code']?.toString().trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team join code copied')));
  }

  Future<void> _createTask() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    var type = 'task';
    var priority = 'normal';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New team item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'task', label: Text('Task')),
                    ButtonSegment(value: 'part_request', label: Text('Part request')),
                    ButtonSegment(value: 'checklist', label: Text('Checklist')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setSheetState(() => type = value.first),
                ),
                const SizedBox(height: 14),
                TextField(controller: title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Details (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) => priority = value ?? 'normal',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add to board'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true || _team == null) return;
    try {
      await widget.api.createTeamBoardTask(
        _team!['team_id'].toString(),
        title: title.text.trim(),
        description: notes.text.trim(),
        taskType: type,
        priority: priority,
        assignedTo: Supabase.instance.client.auth.currentUser?.id,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    final status = task['status']?.toString() ?? 'todo';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(task['title']?.toString() ?? 'Team item'), subtitle: Text(task['description']?.toString() ?? '')),
            if (_canEdit && status != 'doing') ListTile(leading: const Icon(CupertinoIcons.hammer), title: const Text('Mark in progress'), onTap: () => Navigator.pop(context, 'doing')),
            if (_canEdit && status != 'done') ListTile(leading: const Icon(CupertinoIcons.check_mark_circled), title: const Text('Mark complete'), onTap: () => Navigator.pop(context, 'done')),
            if (_canEdit && status != 'todo') ListTile(leading: const Icon(CupertinoIcons.arrow_counterclockwise), title: const Text('Move to To do'), onTap: () => Navigator.pop(context, 'todo')),
            if (_canEdit) ListTile(leading: const Icon(CupertinoIcons.delete, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(context, 'delete')),
          ],
        ),
      ),
    );
    if (action == null || _team == null) return;
    try {
      final teamId = _team!['team_id'].toString();
      final taskId = task['task_id'].toString();
      if (action == 'delete') {
        await widget.api.deleteTeamBoardTask(teamId, taskId);
      } else {
        await widget.api.updateTeamBoardTask(teamId, taskId, {'status': action});
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Board'),
        actions: [IconButton(onPressed: _load, icon: const Icon(CupertinoIcons.refresh), tooltip: 'Refresh')],
      ),
      floatingActionButton: _team != null && _canEdit
          ? FloatingActionButton(onPressed: _createTask, child: const Icon(CupertinoIcons.add))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _MessageState(title: 'Couldn’t load Team Board', message: _error!, action: () => _load())
              : _team == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Set up your team', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            const Text('Create a Team Board as an owner, or join one with a code.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
                            const SizedBox(height: 20),
                            FilledButton(onPressed: _createTeam, child: const Text('Create Team Board')),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () async {
                                await showJoinTeamDialog(context, widget.api);
                                await _load();
                              },
                              child: const Text('Enter join code'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                              title: Text(_team!['name']?.toString() ?? 'Team', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                              subtitle: Text('${(_team!['program']?.toString() ?? '').toUpperCase()} · ${_role == 'owner' ? 'Owner' : _role[0].toUpperCase() + _role.substring(1)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_role == 'owner' && (_team?['join_code']?.toString().isNotEmpty ?? false))
                                    IconButton(
                                      onPressed: _copyJoinCode,
                                      icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
                                      tooltip: 'Copy join code',
                                    ),
                                  if (_teams.length > 1) const Icon(CupertinoIcons.chevron_down, size: 16),
                                ],
                              ),
                              onTap: _teams.length > 1 ? _chooseTeam : null,
                            ),
                          ),
                          if (_tasks.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _MessageState(
                                title: 'Your team is clear',
                                message: _canEdit ? 'Add a task, part request, or checklist item.' : 'There are no open team items.',
                                actionLabel: _canEdit ? 'Add first item' : null,
                                action: _canEdit ? _createTask : null,
                              ),
                            )
                          else
                            SliverList.separated(
                              itemCount: _tasks.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 58),
                              itemBuilder: (context, index) {
                                final task = _tasks[index];
                                final done = task['status'] == 'done';
                                final type = task['task_type']?.toString() ?? 'task';
                                return ListTile(
                                  leading: Icon(
                                    done
                                        ? CupertinoIcons.check_mark_circled_solid
                                        : type == 'part_request'
                                            ? CupertinoIcons.cube_box
                                            : type == 'checklist'
                                                ? CupertinoIcons.list_bullet
                                                : CupertinoIcons.circle,
                                    color: done ? AppColors.muted : AppColors.accent,
                                    size: 22,
                                  ),
                                  title: Text(task['title']?.toString() ?? 'Team item', style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
                                  subtitle: Text(_subtitle(task)),
                                  trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                                  onTap: () => _openTask(task),
                                );
                              },
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
    );
  }

  String _subtitle(Map<String, dynamic> task) {
    final parts = <String>[];
    if (task['status'] == 'doing') parts.add('In progress');
    if (task['priority'] == 'high') parts.add('High priority');
    if (task['priority'] == 'urgent') parts.add('Urgent');
    if (task['assigned_to'] == Supabase.instance.client.auth.currentUser?.id) parts.add('Assigned to you');
    return parts.isEmpty ? 'To do' : parts.join(' · ');
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.title, required this.message, this.actionLabel = 'Retry', this.action});

  final String title;
  final String message;
  final String? actionLabel;
  final FutureOr<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: () => action!(), child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
