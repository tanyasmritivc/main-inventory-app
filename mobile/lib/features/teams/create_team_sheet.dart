import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import 'team_categories.dart';

class CreateTeamSheet extends StatefulWidget {
  const CreateTeamSheet({super.key, required this.api});
  final ApiClient api;

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _custom = TextEditingController();
  late final String? _account = Supabase.instance.client.auth.currentUser?.id;
  String? _category;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_account != Supabase.instance.client.auth.currentUser?.id) {
      setState(
        () => _error = 'Your account changed. Close this form and try again.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final team = await widget.api.createTeam(
        name: _name.text.trim(),
        program: _category!,
        customCategory: _category == 'custom' ? _custom.text.trim() : null,
      );
      if (!mounted) return;
      if (_account != Supabase.instance.client.auth.currentUser?.id) {
        Navigator.pop(context);
        return;
      }
      if ((team['team_id']?.toString() ?? '').isEmpty) {
        throw const FormatException(
          'The team could not be confirmed. Please try again.',
        );
      }
      Navigator.pop(context, team);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeError(error).$1;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  'Create Team',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                AppText(
                  'Bring people and inventory together at home, at work, or in your community.',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('team-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Team name'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter a team name'
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('team-category'),
                  isExpanded: true,
                  menuMaxHeight: 360,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Team category'),
                  hint: const AppText('Choose a category'),
                  items: [
                    for (final category in teamCategories.entries)
                      DropdownMenuItem(
                        value: category.key,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AppText(category.value),
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Choose a category' : null,
                ),
                if (_category == 'custom') ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('team-custom-category'),
                    controller: _custom,
                    enabled: !_saving,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Custom category',
                      hintText: 'e.g. Costume department',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your category'
                        : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: AppText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('team-save'),
                  onPressed: _saving ? null : _save,
                  child: AppText(_saving ? 'Creating...' : 'Create Team'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const AppText('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
