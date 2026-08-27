import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class SpaceMembersPage extends StatefulWidget {
  final String shareId;
  final String spaceName;
  final ApiClient api;
  const SpaceMembersPage({required this.shareId, required this.spaceName, required this.api, super.key});
  @override
  State<SpaceMembersPage> createState() => _SpaceMembersPageState();
}

class _SpaceMembersPageState extends State<SpaceMembersPage> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.api.getShareMembers(shareId: widget.shareId);
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF0A84FF), const Color(0xFF30D158),
      const Color(0xFFFF9F0A), const Color(0xFFFF375F),
      const Color(0xFFBF5AF2), const Color(0xFF5E5CE6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.spaceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            const Text('Team members', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 11)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${_members.length} ${_members.length == 1 ? 'member' : 'members'}',
                  style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4),
                ),
                const SizedBox(height: 12),
                ..._members.map((member) {
                  final name = member['display_name'] as String? ?? 'Unknown';
                  final email = member['email'] as String? ?? '';
                  final role = member['role'] as String? ?? 'member';
                  final color = _avatarColor(name);
                  final isOwner = role == 'owner';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x0DFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1AFBBF24),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Owner', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                              if (email.isNotEmpty)
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse('mailto:$email');
                                    if (await canLaunchUrl(uri)) launchUrl(uri);
                                  },
                                  child: Row(
                                    children: [
                                      Text(email, style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.open_in_new, color: Color(0x4DFFFFFF), size: 10),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
