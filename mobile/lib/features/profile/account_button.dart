import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/profile_store.dart';
import '../../core/ui/member_avatar.dart';
import 'account_page.dart';

/// Account identity, independent of organization/workspace/inventory roles.
class AccountButton extends StatefulWidget {
  const AccountButton({super.key, required this.api});
  final ApiClient api;
  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  late final ApiClient _api;
  late final ProfileStore _profile;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _api = ApiClient.forAccount(widget.api, widget.api.accountId ?? '');
    _profile = ProfileStore(api: _api);
    unawaited(_profile.load());
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountPage(api: _api, store: _profile),
        ),
      );
      if (mounted) unawaited(_profile.load(force: true));
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _profile,
    builder: (context, _) => IconButton(
      tooltip: 'Your profile',
      onPressed: _open,
      icon: _profile.photoUrl.isEmpty
          ? const Icon(CupertinoIcons.person_crop_circle, size: 28)
          : MemberAvatar(
              key: ValueKey(_profile.photoRevision),
              name: _profile.name,
              photoUrl: _profile.photoUrl,
              colorHex: _profile.color,
              size: 28,
            ),
    ),
  );
}
