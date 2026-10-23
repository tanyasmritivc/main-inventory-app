import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/profile_store.dart';
import '../../core/ui/member_avatar.dart';
import '../notifications/notifications_page.dart';
import 'profile_page.dart';

/// One avatar tap exposes the actual preferences, without an Account hub.
Future<void> showAccountMenu(
  BuildContext context, {
  required ApiClient api,
  required ProfileStore profile,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheet) => FractionallySizedBox(
    heightFactor: .92,
    child: Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: MemberAvatar(
            name: profile.name,
            photoUrl: profile.photoUrl,
            size: 44,
          ),
          title: Text(profile.name.isEmpty ? 'Your profile' : profile.name),
          subtitle: const Text('Edit profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(sheet).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Profile')),
                body: ProfilePage(api: api, accountOnly: true, store: profile),
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.notifications_none),
          title: const Text('Notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(sheet).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificationsPage(api: api),
            ),
          ),
        ),
        Expanded(
          child: ProfilePage(api: api, settingsOnly: true, store: profile),
        ),
      ],
    ),
  ),
);
