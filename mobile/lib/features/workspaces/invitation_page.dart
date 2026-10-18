import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_text.dart';
import '../../core/invitation.dart';
import '../../core/invitation_destination.dart';
import '../sharing/invitation_navigation.dart';

/// Preview is read-only. Only the explicit Accept button grants membership.
class AccessInvitationPage extends StatefulWidget {
  const AccessInvitationPage({
    super.key,
    required this.api,
    this.code,
    this.invitationId,
    this.returnDecision = false,
  });
  final ApiClient api;
  final bool returnDecision;
  final String? code, invitationId;
  @override
  State<AccessInvitationPage> createState() => _AccessInvitationPageState();
}

class _AccessInvitationPageState extends State<AccessInvitationPage> {
  Map<String, dynamic>? _invitation;
  Object? _error;
  bool _busy = false;
  late final ApiClient _api;
  late final String _owner;
  StreamSubscription<AuthState>? _auth;
  bool get _sameAccount => widget.api.accountId == _owner;
  bool get _expired {
    final expiry = DateTime.tryParse(
      _invitation?['expires_at']?.toString() ?? '',
    );
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _owner = widget.api.accountId ?? '';
    _api = ApiClient.forAccount(widget.api, _owner);
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted && !_sameAccount) {
        setState(() {
          _invitation = null;
          _error = null;
        });
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _invitation = null;
    });
    try {
      var code = widget.code?.trim();
      if (code != null) {
        final uri = Uri.tryParse(code);
        if (uri != null && uri.hasScheme) {
          final linked = Invitation.fromUri(uri);
          if (linked?.kind != 'access') {
            throw const FormatException(
              'Use a FindEZ access invitation link or code.',
            );
          }
          code = linked!.code;
        }
        code = code.toUpperCase();
        if (!RegExp(r'^[A-Z2-9]{12}$').hasMatch(code)) {
          throw const FormatException(
            'Enter the 12-character invitation code.',
          );
        }
      }
      final data = await _api.collaboration(
        '/access-invitations/preview',
        method: 'POST',
        data: {
          if (code != null)
            'code': code
          else
            'invitation_id': widget.invitationId,
        },
      );
      final invitation = Map<String, dynamic>.from(data['invitation'] as Map);
      if (mounted && _sameAccount) setState(() => _invitation = invitation);
    } catch (error) {
      if (mounted && _sameAccount) setState(() => _error = error);
    } finally {
      if (mounted && _sameAccount) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String action) async {
    if (_busy || _invitation == null || !_sameAccount || _expired) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _api.collaboration(
        '/access-invitations/${_invitation!['invitation_id']}/decision',
        method: 'POST',
        data: {'action': action},
      );
      final invitation = Map<String, dynamic>.from(data['invitation'] as Map);
      if (invitation['invitation_id'] != _invitation!['invitation_id'] ||
          invitation['scope'] != _invitation!['scope'] ||
          invitation['resource_id'] != _invitation!['resource_id'] ||
          invitation['status'] !=
              (action == 'accept' ? 'accepted' : 'declined')) {
        throw const FormatException(
          'Decision could not be confirmed. Refresh before retrying.',
        );
      }
      if (action == 'accept') InvitationDestination.fromAccess(invitation);
      if (mounted && _sameAccount) setState(() => _invitation = invitation);
    } catch (error) {
      if (mounted && _sameAccount) setState(() => _error = error);
    } finally {
      if (mounted && _sameAccount) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  void _done() {
    if (!_sameAccount || _busy || _invitation == null) return;
    final accepted = _invitation!['status'] == 'accepted';
    try {
      final result = accepted
          ? InvitationDestination.fromAccess(_invitation!).toResult()
          : <String, dynamic>{'accepted': false};
      if (widget.returnDecision) {
        Navigator.pop(context, result);
      } else if (accepted) {
        openInvitationResult(context, _api, result);
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Invitation')),
    body: !_sameAccount
        ? const Center(
            child: AppText(
              'Your account changed. Reopen the invitation with the invited account.',
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                AppText(describeError(_error!).$1),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const AppText('Retry'),
                ),
              ],
              if (_invitation != null) ...[
                AppText(
                  (_invitation!['name'] ?? _invitation!['resource_name'])
                      .toString(),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 12),
                AppText('${_invitation!['scope']} | ${_invitation!['role']}'),
                const SizedBox(height: 12),
                AppText('Status: ${_invitation!['status']}'),
                if (_invitation!['expires_at'] != null)
                  AppText('Expires: ${_invitation!['expires_at']}'),
                if (_invitation!['status'] == 'pending' && _expired)
                  const AppText(
                    'This invitation has expired. Ask the sender for a new one.',
                  ),
                if (_invitation!['status'] == 'pending' && !_expired) ...[
                  const SizedBox(height: 20),
                  const AppText(
                    'Joining requires your consent. Access is checked again when you accept.',
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _decide('accept'),
                    child: const AppText('Accept invitation'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _decide('decline'),
                    child: const AppText('Decline'),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _busy ? null : _done,
                    child: AppText(
                      _invitation!['status'] == 'accepted'
                          ? 'Open ${_invitation!['scope']}'
                          : 'Done',
                    ),
                  ),
                ],
              ],
            ],
          ),
  );
}
