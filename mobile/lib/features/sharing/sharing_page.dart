import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import 'shared_inventory_page.dart';
import 'space_members_page.dart';

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  List<Map<String, dynamic>> _myShares = [];
  List<Map<String, dynamic>> _joinedShares = [];
  bool _loading = true;

  dio.Dio _backend() {
    final d = dio.Dio(
      dio.BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    d.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return d;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final backend = _backend();
      final my = await backend.get<dynamic>('/sharing/my-shares');
      final joined = await backend.get<dynamic>('/sharing/joined');
      if (!mounted) return;
      setState(() {
        _myShares = (my.data as List? ?? []).cast<Map<String, dynamic>>();
        _joinedShares =
            (joined.data as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t load shared spaces.')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _revokeShare(String shareId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: const Text('Revoke share?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Members will lose access immediately.',
          style: TextStyle(color: Color(0x73FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0x73FFFFFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _backend().delete<dynamic>('/sharing/$shareId');
      setState(() =>
          _myShares.removeWhere((s) => s['share_id'] == shareId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not revoke share.')),
        );
      }
    }
  }

  void _showMembers(Map<String, dynamic> share) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MembersSheet(
        share: share,
        backend: _backend(),
      ),
    );
  }

  void _showCreateShare() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CreateShareSheet(
        backend: _backend(),
        onCreated: (share) {
          Navigator.pop(ctx);
          _showShareCode(share);
          _load();
        },
      ),
    );
  }

  void _showShareCode(Map<String, dynamic> share) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShareCodeSheet(
        share: share,
        onDone: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _showJoinShare() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _JoinShareSheet(
        backend: _backend(),
        onJoined: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text(
          'Team Sharing',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('MY SHARES'),
                  if (_myShares.isEmpty) ...[
                    _glassCard(
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline,
                                size: 32, color: Color(0x4DFFFFFF)),
                            const SizedBox(height: 12),
                            const Text(
                              'No active shares',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create a share so teammates can view your inventory.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0x73FFFFFF), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    for (final share in _myShares)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _glassCard(
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (share['share_name'] ?? '').toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.25)),
                                            ),
                                            child: Text(
                                              (share['share_code'] ?? '')
                                                  .toString(),
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            share['permission'] == 'edit'
                                                ? '✏️ Can edit'
                                                : '👁 View only',
                                            style: const TextStyle(
                                                color: Color(0x73FFFFFF),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${share['member_count'] ?? 0} members',
                                        style: const TextStyle(
                                            color: Color(0x4DFFFFFF),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    _iconBtn(
                                      Icons.copy,
                                      () {
                                        final code = (share['share_code'] ?? '')
                                            .toString();
                                        Clipboard.setData(
                                            ClipboardData(text: code));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content:
                                              Text('Code copied: $code'),
                                        ));
                                      },
                                    ),
                                    _iconBtn(
                                      Icons.people,
                                      () => _showMembers(share),
                                    ),
                                    _iconBtn(
                                      Icons.link_off,
                                      () => _revokeShare(
                                          share['share_id'].toString()),
                                      color: const Color(0x73FF3B30),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF636366).withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _showCreateShare,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                            side: BorderSide(
                              color: const Color(0xFF636366).withValues(alpha: 0.60),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Text(
                          '+ Create Share',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sectionLabel('JOINED SHARES'),
                  const SizedBox(height: 12),
                  if (_joinedShares.isEmpty)
                    _glassCard(
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Not in any team yet',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Enter a share code to view a teammate's inventory.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0x73FFFFFF), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final membership in _joinedShares)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildJoinedCard(membership),
                      ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showJoinShare,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Join a Share',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildJoinedCard(Map<String, dynamic> membership) {
    final shareData =
        (membership['team_shares'] as Map?)?.cast<String, dynamic>() ?? {};
    final shareName = (shareData['share_name'] ?? '').toString();
    final permission = (shareData['permission'] ?? 'view').toString();
    final shareId = (shareData['share_id'] ?? '').toString();

    return _glassCard(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shareName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              permission == 'edit' ? '✏️ Can edit' : '👁 View only',
              style:
                  const TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SharedInventoryPage(
                            shareId: shareId,
                            shareName: shareName,
                            permission: permission,
                            api: ApiClient(baseUrl: AppConfig.apiBaseUrl),
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('View Inventory',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpaceMembersPage(
                        shareId: shareId,
                        spaceName: shareName,
                        api: ApiClient(baseUrl: AppConfig.apiBaseUrl),
                      ),
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Members', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface2(ctx),
                        title: const Text('Leave Space', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Leave "$shareName"? You will lose access to this shared inventory.',
                          style: const TextStyle(color: Color(0x73FFFFFF)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Color(0x73FFFFFF))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Leave', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await _backend().delete<dynamic>('/sharing/$shareId/leave');
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Left "$shareName"')),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to leave. Try again.')),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text('Leave', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _glassCard(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
            ),
            child: child,
          ),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap,
          {Color color = const Color(0x73FFFFFF)}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _CreateShareSheet extends StatefulWidget {
  const _CreateShareSheet({required this.backend, required this.onCreated});

  final dio.Dio backend;
  final void Function(Map<String, dynamic>) onCreated;

  @override
  State<_CreateShareSheet> createState() => _CreateShareSheetState();
}

class _CreateShareSheetState extends State<_CreateShareSheet> {
  final _nameCtrl = TextEditingController();
  StreamSubscription<AuthState>? _authSub;
  String _permission = 'view';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a share name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await widget.backend.post<Map<String, dynamic>>(
        '/sharing/create',
        data: {'share_name': name, 'permission': _permission},
      );
      final share = res.data ?? {};
      widget.onCreated(share);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e).$1)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a Share',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _label('Share Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Robotics Team 2024',
                hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
                filled: true,
                fillColor: const Color(0xFF171717),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x14FFFFFF), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x14FFFFFF), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x33FFFFFF), width: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Permission'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _permCard(
                        'view',
                        Icons.visibility_outlined,
                        'View only',
                        'Can browse, cannot edit')),
                const SizedBox(width: 10),
                Expanded(
                    child: _permCard(
                        'edit',
                        Icons.edit_outlined,
                        'Can edit',
                        'Can add and update items')),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                  elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2)
                    : const Text('Create Share',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permCard(
      String value, IconData icon, String label, String subtitle) {
    final isSelected = _permission == value;
    return GestureDetector(
      onTap: () => setState(() => _permission = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : const Color(0x14FFFFFF),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color:
                    isSelected ? Colors.white : const Color(0x4DFFFFFF),
                size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0x73FFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? const Color(0x73FFFFFF)
                    : const Color(0x4DFFFFFF),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0x4DFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      );
}

class _ShareCodeSheet extends StatelessWidget {
  const _ShareCodeSheet({required this.share, required this.onDone});

  final Map<String, dynamic> share;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final code = (share['share_code'] ?? '').toString();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share created!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this code with your teammates',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Center(
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code copied: $code')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
                elevation: 0,
              ),
              child: const Text('Copy Code',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x33FFFFFF)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
              ),
              child: const Text('Done',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinShareSheet extends StatefulWidget {
  const _JoinShareSheet({required this.backend, required this.onJoined});

  final dio.Dio backend;
  final VoidCallback onJoined;

  @override
  State<_JoinShareSheet> createState() => _JoinShareSheetState();
}

class _JoinShareSheetState extends State<_JoinShareSheet> {
  final _ctrl = TextEditingController();
  StreamSubscription<AuthState>? _authSub;
  String? _joinError;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      final res = await widget.backend.post<Map<String, dynamic>>(
        '/sharing/join',
        data: {'share_code': code},
      );
      final name =
          (res.data?['share_name'] ?? '').toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${name.isNotEmpty ? name : code}!')),
        );
        widget.onJoined();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joinError = friendlyApiError(e, fallback: 'Failed to join. Check the code and try again.'));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Join a Share',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter the 6-character code from your team owner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'AB3X9K',
                hintStyle: const TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontFamily: 'monospace',
                  fontSize: 28,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: const Color(0xFF171717),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x14FFFFFF), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x14FFFFFF), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0x33FFFFFF), width: 0.5),
                ),
              ),
            ),
            if (_joinError != null) ...[
              const SizedBox(height: 8),
              Text(
                _joinError!,
                style: const TextStyle(
                    color: Color(0xFFFF3B30), fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _joining ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                  elevation: 0,
                ),
                child: _joining
                    ? const CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2)
                    : const Text('Join',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersSheet extends StatefulWidget {
  const _MembersSheet({required this.share, required this.backend});

  final Map<String, dynamic> share;
  final dio.Dio backend;

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _loadError;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    final shareId = widget.share['share_id'].toString();
    try {
      final res =
          await widget.backend.get<dynamic>('/sharing/$shareId/members');
      if (!mounted) return;
      setState(() {
        _members =
            (res.data as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = describeError(e).$1);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Members',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          else if (_loadError != null && _members.isEmpty)
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError!,
                    style: const TextStyle(
                        color: Color(0x73FFFFFF), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else if (_members.isEmpty)
            const Text('No members yet.',
                style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14))
          else
            for (final m in _members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Color(0x4DFFFFFF), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (m['member_user_id'] ?? '').toString(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final shareId =
                            widget.share['share_id'].toString();
                        final memberId =
                            (m['member_user_id'] ?? '').toString();
                        try {
                          await widget.backend.delete<dynamic>(
                              '/sharing/$shareId/members/$memberId');
                          _load();
                        } catch (e) {
                          debugPrint('[MembersSheet] remove member error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Couldn\'t remove member. Try again.'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0x73FF3B30)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
