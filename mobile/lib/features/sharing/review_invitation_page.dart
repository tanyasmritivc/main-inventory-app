import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/invitation.dart';
import '../workspaces/invitation_page.dart';
import 'invitation_dialog.dart';

/// Manual entry uses exactly the same preview/consent flow as incoming links.
class ReviewInvitationPage extends StatefulWidget {
  const ReviewInvitationPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ReviewInvitationPage> createState() => _ReviewInvitationPageState();
}

class _ReviewInvitationPageState extends State<ReviewInvitationPage> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;
  Future<void> _review() async {
    if (_busy) return;
    final owner = widget.api.accountId;
    final value = _text.text.trim();
    final uri = Uri.tryParse(value);
    final linked = uri != null && uri.hasScheme
        ? Invitation.fromUri(uri)
        : null;
    final code = linked?.code ?? value.toUpperCase();
    if ((uri?.hasScheme == true && linked == null) ||
        (!Invitation.validCode('access', code) &&
            !Invitation.validCode('team', code))) {
      setState(
        () => _error =
            'Use a FindEZ invitation link or a 6- or 12-character code.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? result;
      if (linked?.kind == 'access' || Invitation.validCode('access', code)) {
        result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => AccessInvitationPage(
              api: widget.api,
              code: code,
              returnDecision: true,
            ),
          ),
        );
      } else {
        final kind =
            linked?.kind ??
            await showDialog<String>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Invitation type'),
                children: [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, 'team'),
                    child: const Text('Workspace'),
                  ),
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, 'space'),
                    child: const Text('Shared Space'),
                  ),
                ],
              ),
            );
        if (!mounted || kind == null || widget.api.accountId != owner) return;
        result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => InvitationDialog(
            api: widget.api,
            invitation: Invitation(
              kind: kind,
              code: code,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
            userId: owner ?? '',
          ),
        );
      }
      if (mounted &&
          widget.api.accountId == owner &&
          result?['accepted'] == true) {
        Navigator.pop(context, result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review invitation')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _text,
          enabled: !_busy,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Invitation link or code',
          ),
          onSubmitted: (_) => _review(),
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _review,
          child: const Text('Review invitation'),
        ),
      ],
    ),
  );
}
