import '../../core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/invitation.dart';
import '../../core/ui/app_colors.dart';
import 'package:mobile/core/ui/app_text.dart';

class InvitationDialog extends StatefulWidget {
  const InvitationDialog({
    super.key,
    required this.api,
    required this.invitation,
    required this.userId,
  });
  final ApiClient api;
  final Invitation invitation;
  final String userId;
  @override
  State<InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<InvitationDialog> {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = true;
  bool get _sameAccount =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.previewInvitation(
        widget.invitation.kind,
        widget.invitation.code,
      );
      if (!mounted || !_sameAccount) return;
      setState(() => _preview = data);
    } catch (error) {
      if (mounted && _sameAccount) {
        setState(() => _error = friendlyApiError(error));
      }
    } finally {
      if (mounted && _sameAccount) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy || !_sameAccount || _preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Always redeem again: a preview is not authorization, and an owner may
      // have revoked or rotated the code while this dialog was open.
      final result = widget.invitation.kind == 'team'
          ? await widget.api.joinTeam(widget.invitation.code)
          : await widget.api.joinShare(widget.invitation.code);
      if (!mounted || !_sameAccount) return;
      final destination = widget.invitation.kind == 'team'
          ? Map<String, dynamic>.from(result['membership'] ?? const {})
          : result;
      Navigator.of(context).pop(<String, dynamic>{
        ..._preview!,
        ...destination,
        if (destination['owner_user_id'] == widget.userId) 'permission': 'edit',
        'accepted': true,
      });
    } catch (error) {
      if (mounted && _sameAccount) {
        setState(() => _error = friendlyApiError(error));
      }
    } finally {
      if (mounted && _sameAccount) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.invitation.kind == 'team';
    final joined = _preview?['already_joined'] == true;
    final name = _preview?['name']?.toString();
    final access = team
        ? 'Team member'
        : _preview?['permission'] == 'edit'
        ? 'Can edit'
        : 'View only';
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: AppTheme.adaptive(context, AppColors.surface),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                team ? 'TEAM INVITATION' : 'SPACE INVITATION',
                style: TextStyle(
                  color: AppTheme.foreground(context, AppColors.muted),
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              AppText(
                name ?? 'Your invitation',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              if (_preview != null) ...[
                AppText(
                  joined
                      ? 'You already have access. Open it to continue.'
                      : team
                      ? 'Join this team to work together in FindEZ.'
                      : 'Join this space to see its inventory in FindEZ.',
                  style: TextStyle(
                    color: AppTheme.foreground(context, AppColors.muted),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                AppText(
                  'Access: $access',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      AppText('Checking invitation...'),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: AppText(
                    _error!,
                    style: TextStyle(
                      color: AppTheme.foreground(context, AppColors.danger),
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              if (_preview != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.action,
                    foregroundColor: AppTheme.onAction,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _accept,
                  child: AppText(
                    _busy
                        ? 'Please wait...'
                        : joined
                        ? 'Open ${team ? 'team' : 'space'}'
                        : 'Join ${team ? 'team' : 'space'}',
                  ),
                ),
              if (_preview == null && !_busy)
                OutlinedButton(
                  onPressed: _load,
                  child: const AppText('Try again'),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.adaptive(context, AppColors.muted),
                ),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(<String, dynamic>{'accepted': false}),
                child: const AppText('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
