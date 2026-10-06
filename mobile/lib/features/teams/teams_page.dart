import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';
import '../../core/upgrade_sheet.dart';
import 'team_workspace_page.dart';
import 'package:mobile/core/ui/app_text.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  List<Map<String, dynamic>> _teams = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await widget.api.listTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
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

  Future<void> _createTeam() async {
    final name = TextEditingController();
    var program = 'robotics';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  'Create Team',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                AppText(
                  'A team brings people, spaces, and work together.',
                  style: TextStyle(
                    color: AppTheme.foreground(context, AppColors.muted),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Team name or number',
                  ),
                  style: AppTypography.bodyStyleOf(context),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: program,
                  decoration: const InputDecoration(labelText: 'Team type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'robotics',
                      child: AppText('Robotics Team'),
                    ),
                    DropdownMenuItem(
                      value: 'ftc',
                      child: AppText('FIRST Tech Challenge'),
                    ),
                    DropdownMenuItem(
                      value: 'frc',
                      child: AppText('FIRST Robotics Competition'),
                    ),
                    DropdownMenuItem(
                      value: 'fll',
                      child: AppText('FIRST LEGO League'),
                    ),
                    DropdownMenuItem(
                      value: 'vex',
                      child: AppText('VEX Robotics'),
                    ),
                    DropdownMenuItem(
                      value: 'education',
                      child: AppText('School or Classroom'),
                    ),
                    DropdownMenuItem(
                      value: 'makerspace',
                      child: AppText('Makerspace or Workshop'),
                    ),
                    DropdownMenuItem(
                      value: 'club',
                      child: AppText('Club or Community Group'),
                    ),
                    DropdownMenuItem(
                      value: 'business',
                      child: AppText('Business or Operations'),
                    ),
                    DropdownMenuItem(value: 'other', child: AppText('Other')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => program = value ?? 'robotics'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const AppText('Create Team'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    try {
      final team = await widget.api.createTeam(
        name: name.text.trim(),
        program: program,
      );
      await _load();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamWorkspacePage(
            api: widget.api,
            initialTeamId: team['team_id']?.toString(),
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  Future<void> _joinTeam() async {
    final joined = await showJoinTeamDialog(context, widget.api);
    if (joined) await _load();
  }

  Future<void> _openTeam(Map<String, dynamic> team) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamWorkspacePage(
          api: widget.api,
          initialTeamId: team['team_id']?.toString(),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _TeamsMessage(
        title: 'Couldn’t load teams',
        message: _error!,
        actionLabel: 'Try Again',
        action: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
        children: [
          Row(
            children: [
              Expanded(
                child: _TeamAction(
                  icon: CupertinoIcons.add,
                  title: 'Create Team',
                  onTap: _createTeam,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TeamAction(
                  icon: CupertinoIcons.person_badge_plus,
                  title: 'Join Team',
                  onTap: _joinTeam,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_teams.isEmpty)
            const _TeamsMessage(
              title: 'Teams keep work together',
              message:
                  'Create a team for your group, or join one with a team code. Shared Spaces remain separate.',
            )
          else ...[
            AppText(
              'Your Teams',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, const Color(0xFF19191B)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.adaptive(
                    context,
                    Colors.white.withValues(alpha: .08),
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _teams.length; i++) ...[
                    _TeamRow(
                      team: _teams[i],
                      onTap: () => _openTeam(_teams[i]),
                    ),
                    if (i != _teams.length - 1)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: AppTheme.adaptive(
                          context,
                          Colors.white.withValues(alpha: .08),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamAction extends StatelessWidget {
  const _TeamAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.adaptive(context, const Color(0xFF19191B)),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accentForeground(context), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team, required this.onTap});

  final Map<String, dynamic> team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = team['role']?.toString() ?? 'member';
    final program = team['program']?.toString().toUpperCase() ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(
        CupertinoIcons.person_2,
        color: AppTheme.accentForeground(context),
        size: 22,
      ),
      title: AppText(
        team['name']?.toString() ?? 'Team',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: AppText(
        [
          if (program.isNotEmpty) program,
          role == 'owner' ? 'Owner' : role,
        ].join(' · '),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_forward,
        color: AppTheme.foreground(context, AppColors.muted),
        size: 16,
      ),
      onTap: onTap,
    );
  }
}

class _TeamsMessage extends StatelessWidget {
  const _TeamsMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
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
            const SizedBox(height: 18),
            FilledButton(onPressed: action, child: AppText(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
