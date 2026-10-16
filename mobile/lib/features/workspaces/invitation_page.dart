import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_text.dart';

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
  @override
  void initState() {
    super.initState();
    _api = ApiClient.forAccount(widget.api, widget.api.accountId ?? '');
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
          if (uri.scheme != 'https' ||
              uri.userInfo.isNotEmpty ||
              (uri.hasPort && uri.port != 443) ||
              !['findez.ai', 'www.findez.ai'].contains(uri.host) ||
              uri.path != '/join/access') {
            throw const FormatException(
              'Use a FindEZ access invitation link or code.',
            );
          }
          code = uri.queryParameters['code'];
        }
        code = code?.toUpperCase();
        if (code == null || !RegExp(r'^[A-Z2-9]{12}$').hasMatch(code)) {
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
      if (mounted) setState(() => _invitation = invitation);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String action) async {
    if (_busy || _invitation == null) return;
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
      if (!['accepted', 'declined'].contains(invitation['status'])) {
        throw const FormatException(
          'Decision could not be confirmed. Refresh before retrying.',
        );
      }
      if (mounted) setState(() => _invitation = invitation);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Invitation')),
    body: ListView(
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
            (_invitation!['name'] ?? _invitation!['resource_name']).toString(),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 12),
          AppText('${_invitation!['scope']} | ${_invitation!['role']}'),
          const SizedBox(height: 12),
          AppText('Status: ${_invitation!['status']}'),
          if (_invitation!['expires_at'] != null)
            AppText('Expires: ${_invitation!['expires_at']}'),
          if (_invitation!['status'] == 'pending') ...[
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
              onPressed: () => widget.returnDecision
                  ? Navigator.pop(context, <String, dynamic>{
                      'accepted': _invitation!['status'] == 'accepted',
                    })
                  : Navigator.pop(context),
              child: const AppText('Done'),
            ),
          ],
        ],
      ],
    ),
  );
}
