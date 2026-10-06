import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/member_avatar.dart';
import '../../core/ui/glass_fab.dart';
import 'package:mobile/core/ui/app_text.dart';

class TeamBoardPage extends StatefulWidget {
  const TeamBoardPage({super.key, required this.api, this.initialTeamId});

  final ApiClient api;
  final String? initialTeamId;

  @override
  State<TeamBoardPage> createState() => _TeamBoardPageState();
}

class _TeamBoardPageState extends State<TeamBoardPage> {
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _members = const [];
  Map<String, dynamic>? _team;
  String _role = 'viewer';
  bool _loading = true;
  String? _error;
  String _filter = 'open';

  bool get _canEdit => _role != 'viewer';

  @override
  void initState() {
    super.initState();
    unawaited(_load(teamId: widget.initialTeamId));
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
        final results = await Future.wait([
          widget.api.getTeamBoard(selected['team_id'].toString()),
          widget.api.getTeamMembers(selected['team_id'].toString()),
        ]);
        final board = results[0] as Map<String, dynamic>;
        tasks = List<Map<String, dynamic>>.from(board['tasks'] ?? const []);
        _members = List<Map<String, dynamic>>.from(results[1] as List);
        role = board['role']?.toString() ?? 'viewer';
      }
      if (!mounted) return;
      setState(() {
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

  Future<void> _createTask() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    var type = 'task';
    var priority = 'normal';
    var assignedTo = '';
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
                const AppText(
                  'New team item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'task', label: AppText('Task')),
                    ButtonSegment(
                      value: 'part_request',
                      label: AppText('Part request'),
                    ),
                    ButtonSegment(
                      value: 'checklist',
                      label: AppText('Checklist'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setSheetState(() => type = value.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                  style: AppTypography.bodyStyleOf(context),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                  ),
                  style: AppTypography.bodyStyleOf(context),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: AppText('Normal')),
                    DropdownMenuItem(value: 'high', child: AppText('High')),
                    DropdownMenuItem(value: 'urgent', child: AppText('Urgent')),
                  ],
                  onChanged: (value) => priority = value ?? 'normal',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: assignedTo,
                  decoration: const InputDecoration(labelText: 'Assigned to'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: AppText('Unassigned'),
                    ),
                    for (final member in _members)
                      DropdownMenuItem(
                        value: member['user_id']?.toString() ?? '',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MemberAvatar(
                              name:
                                  member['display_name']?.toString() ??
                                  'Team member',
                              photoUrl: member['avatar_url']?.toString(),
                              colorHex: member['avatar_color']?.toString(),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            AppText(
                              member['display_name']?.toString() ??
                                  'Team member',
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => assignedTo = value ?? '',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const AppText('Add to board'),
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
        assignedTo: assignedTo.isEmpty ? null : assignedTo,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
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
            ListTile(
              title: AppText(task['title']?.toString() ?? 'Team item'),
              subtitle: AppText(task['description']?.toString() ?? ''),
            ),
            if (_canEdit && status != 'doing')
              ListTile(
                leading: const Icon(CupertinoIcons.hammer),
                title: const AppText('Mark in progress'),
                onTap: () => Navigator.pop(context, 'doing'),
              ),
            if (_canEdit && status != 'done')
              ListTile(
                leading: const Icon(CupertinoIcons.check_mark_circled),
                title: const AppText('Mark complete'),
                onTap: () => Navigator.pop(context, 'done'),
              ),
            if (_canEdit && status != 'todo')
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_counterclockwise),
                title: const AppText('Move to To do'),
                onTap: () => Navigator.pop(context, 'todo'),
              ),
            if (_canEdit)
              ListTile(
                leading: Icon(
                  CupertinoIcons.delete,
                  color: AppTheme.foreground(context, AppColors.danger),
                ),
                title: AppText(
                  'Delete',
                  style: TextStyle(
                    color: AppTheme.foreground(context, AppColors.danger),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
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
        await widget.api.updateTeamBoardTask(teamId, taskId, {
          'status': action,
        });
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Team Board'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _team != null && _canEdit
          ? GlassFab(onPressed: _createTask, icon: CupertinoIcons.add)
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _MessageState(
              title: 'Couldn’t load Team Board',
              message: _error!,
              action: () => _load(),
            )
          : _team == null
          ? const _MessageState(
              title: 'Team unavailable',
              message: 'Return to Teams and choose another team.',
              actionLabel: null,
            )
          : _buildBoard(),
    );
  }

  Widget _buildBoard() {
    final visible = _tasks.where((task) {
      final done = task['status'] == 'done';
      return _filter == 'completed' ? done : !done;
    }).toList();
    final doing = visible.where((task) => task['status'] == 'doing').toList();
    final todo = visible.where((task) => task['status'] == 'todo').toList();
    final completed = visible
        .where((task) => task['status'] == 'done')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      _team!['name']?.toString() ?? 'Team',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      '${_tasks.where((task) => task['status'] != 'done').length} open · ${doing.length} in progress',
                      style: TextStyle(
                        color: AppTheme.foreground(context, AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              if (_canEdit)
                FilledButton.icon(
                  onPressed: _createTask,
                  icon: const Icon(CupertinoIcons.add, size: 17),
                  label: const AppText('New'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: _filter,
            children: const {
              'open': Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: AppText('Open'),
              ),
              'completed': Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: AppText('Completed'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) setState(() => _filter = value);
            },
          ),
          const SizedBox(height: 22),
          if (visible.isEmpty)
            _BoardEmpty(
              completed: _filter == 'completed',
              canEdit: _canEdit,
              onCreate: _createTask,
            )
          else ...[
            if (doing.isNotEmpty)
              _TaskSection(title: 'IN PROGRESS', tasks: doing, card: _taskCard),
            if (todo.isNotEmpty)
              _TaskSection(title: 'TO DO', tasks: todo, card: _taskCard),
            if (completed.isNotEmpty)
              _TaskSection(
                title: 'COMPLETED',
                tasks: completed,
                card: _taskCard,
              ),
          ],
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final done = task['status'] == 'done';
    final type = task['task_type']?.toString() ?? 'task';
    final priority = task['priority']?.toString() ?? 'normal';
    return Material(
      color: AppTheme.adaptive(context, const Color(0xFF19191B)),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openTask(task),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Icon(
                done
                    ? CupertinoIcons.check_mark_circled_solid
                    : type == 'part_request'
                    ? CupertinoIcons.cube_box
                    : type == 'checklist'
                    ? CupertinoIcons.list_bullet
                    : CupertinoIcons.circle,
                color: done
                    ? AppTheme.foreground(context, AppColors.success)
                    : task['status'] == 'doing'
                    ? AppTheme.foreground(context, AppColors.info)
                    : AppTheme.foreground(context, AppColors.accent),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      task['title']?.toString() ?? 'Team item',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      _subtitle(task),
                      style: TextStyle(
                        color: AppTheme.foreground(context, AppColors.muted),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (priority == 'urgent' || priority == 'high')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (priority == 'urgent'
                                ? AppTheme.adaptive(context, AppColors.danger)
                                : AppTheme.adaptive(context, AppColors.warning))
                            .withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: AppText(
                    priority == 'urgent' ? 'Urgent' : 'High',
                    style: TextStyle(
                      color: priority == 'urgent'
                          ? AppTheme.foreground(context, AppColors.danger)
                          : AppTheme.foreground(context, AppColors.warning),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_forward,
                color: AppTheme.foreground(context, AppColors.muted),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Map<String, dynamic> task) {
    final parts = <String>[];
    if (task['status'] == 'doing') parts.add('In progress');
    if (task['priority'] == 'high') parts.add('High priority');
    if (task['priority'] == 'urgent') parts.add('Urgent');
    final assignedTo = task['assigned_to']?.toString();
    if (assignedTo != null && assignedTo.isNotEmpty) {
      final member = _members
          .where((row) => row['user_id']?.toString() == assignedTo)
          .firstOrNull;
      parts.add(member?['display_name']?.toString() ?? 'Assigned');
    }
    return parts.isEmpty ? 'To do' : parts.join(' · ');
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.tasks,
    required this.card,
  });

  final String title;
  final List<Map<String, dynamic>> tasks;
  final Widget Function(Map<String, dynamic>) card;

  @override
  Widget build(BuildContext context) {
    final sectionColor = title == 'COMPLETED'
        ? AppTheme.adaptive(context, AppColors.success)
        : title == 'IN PROGRESS'
        ? AppTheme.adaptive(context, AppColors.info)
        : AppTheme.adaptive(context, AppColors.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: TextStyle(
              color: sectionColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < tasks.length; index++) ...[
            card(tasks[index]),
            if (index != tasks.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty({
    required this.completed,
    required this.canEdit,
    required this.onCreate,
  });

  final bool completed;
  final bool canEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      child: Column(
        children: [
          Icon(
            completed
                ? CupertinoIcons.check_mark_circled
                : CupertinoIcons.square_list,
            color: AppTheme.foreground(context, AppColors.muted),
            size: 40,
          ),
          const SizedBox(height: 14),
          AppText(
            completed ? 'Nothing completed yet' : 'Your team is clear',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          AppText(
            completed
                ? 'Completed work will stay here for reference.'
                : 'Add a task, part request, or checklist item.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.foreground(context, AppColors.muted),
              height: 1.4,
            ),
          ),
          if (!completed && canEdit) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onCreate,
              child: const AppText('Add First Item'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.message,
    this.actionLabel = 'Retry',
    this.action,
  });

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
            AppText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AppText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, AppColors.muted),
                height: 1.4,
              ),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => action!(),
                child: AppText(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
