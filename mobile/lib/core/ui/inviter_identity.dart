import 'package:flutter/material.dart';
import 'member_avatar.dart';
import 'app_text.dart';

class InviterIdentity extends StatelessWidget {
  const InviterIdentity({super.key, required this.invitation});
  final Map<String, dynamic> invitation;
  @override
  Widget build(BuildContext context) {
    final member = invitation['inviter'] as Map?;
    final name =
        member?['display_name']?.toString() ??
        invitation['invited_by_name']?.toString();
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          MemberAvatar(
            name: name,
            photoUrl: member?['avatar_url']?.toString(),
            colorHex: member?['avatar_color']?.toString(),
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              '${invitation['inviter_label'] ?? 'Invited by'} $name',
            ),
          ),
        ],
      ),
    );
  }
}
