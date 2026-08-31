import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import 'shared_inventory_page.dart';

class ShareSpaceSheet extends StatefulWidget {
  const ShareSpaceSheet({
    super.key,
    required this.spaceName,
    required this.api,
  });

  final String spaceName;
  final ApiClient api;

  @override
  State<ShareSpaceSheet> createState() => _ShareSpaceSheetState();
}

class _ShareSpaceSheetState extends State<ShareSpaceSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _joinCtrl;
  String _permission = 'view';
  bool _loading = false;
  bool _joiningSpace = false;
  String? _createdCode;
  String? _generateError;
  String? _joinError;
  List<dynamic> _myShares = [];
  List<dynamic> _joinedShares = [];
  final ScrollController _shareScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _joinCtrl = TextEditingController();
    _loadShares();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _joinCtrl.dispose();
    _shareScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    try {
      final my = await widget.api.getMyShares();
      final joined = await widget.api.getJoinedShares();
      if (mounted) setState(() { _myShares = my; _joinedShares = joined; });
    } catch (_) {
      // acceptable: read-only sidebar load for the share sheet; sheet is still
      // usable without the share list (user can still generate a new code).
    }
  }

  Future<void> _generateCode() async {
    setState(() { _loading = true; _generateError = null; });
    try {
      final result = await widget.api.createShare(
        shareName: widget.spaceName,
        permission: _permission,
      );
      final code = result['code']?.toString() ??
          result['share_code']?.toString() ?? '';
      if (mounted) {
        setState(() => _createdCode = code);
        await _loadShares();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generateError = friendlyApiError(e));
        // Scroll to reveal active shares so the user can revoke one.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_shareScrollCtrl.hasClients) {
            _shareScrollCtrl.animateTo(
              _shareScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revokeShare(String shareId) async {
    try {
      await widget.api.deleteShare(shareId);
      await _loadShares();
    } catch (e) {
      debugPrint('[ShareSpaceSheet] _revokeShare error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t revoke access. Try again.')),
        );
      }
    }
  }

  Widget _permChip(String value, String label) {
    final selected = _permission == value;
    return GestureDetector(
      onTap: () => setState(() => _permission = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF0066B3).withValues(alpha: 0.30), blurRadius: 10)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0x73FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildShareTab() {
    final spaceShares = _myShares.where(
      (s) => (s['share_name']?.toString() ?? '') == widget.spaceName,
    ).toList();

    return SingleChildScrollView(
      controller: _shareScrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permission',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _permChip('view', 'View only'),
            const SizedBox(width: 8),
            _permChip('edit', 'Can edit'),
          ]),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0066B3).withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _generateCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF0066B3).withValues(alpha: 0.60),
                      width: 1,
                    ),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      )
                    : const Text(
                        'Generate Code',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
              ),
            ),
          ),
          if (_generateError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AF59E0B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x40F59E0B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFFF59E0B), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _generateError!,
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 13,
                              height: 1.45),
                        ),
                        if (spaceShares.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _shareScrollCtrl.animateTo(
                              _shareScrollCtrl.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            ),
                            child: const Text(
                              'Manage shares ↓',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_createdCode != null && _createdCode!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Center(
              child: Text(
                _createdCode!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _createdCode!));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0x14FFFFFF),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Copy Code',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
          if (spaceShares.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'ACTIVE SHARES',
              style: TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
              ),
              child: Column(
                children: spaceShares.asMap().entries.map((e) {
                  final s = e.value;
                  final isLast = e.key == spaceShares.length - 1;
                  final sid = (s['id'] ?? s['share_id'] ?? '').toString();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['share_code']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    s['permission']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Color(0x4DFFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _revokeShare(sid),
                              child: const Text(
                                'Revoke',
                                style: TextStyle(
                                  color: Color(0xFFFF453A),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          height: 0.5,
                          color: const Color(0x14FFFFFF),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _joinSpace() async {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _joinError = 'Enter a 6-character code.');
      return;
    }
    setState(() { _joiningSpace = true; _joinError = null; });
    try {
      await widget.api.joinShare(code);
      _joinCtrl.clear();
      if (mounted) {
        await _loadShares();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined space!')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _joinError = 'Invalid code or already joined.');
    } finally {
      if (mounted) setState(() => _joiningSpace = false);
    }
  }

  Widget _buildJoinedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join a Space',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinCtrl,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    hintText: '6-char code',
                    hintStyle: TextStyle(color: Color(0x4DFFFFFF), fontSize: 14),
                    counterText: '',
                    filled: true,
                    fillColor: Color(0xFF171717),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0066B3).withValues(alpha: 0.25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _joiningSpace ? null : _joinSpace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFF0066B3).withValues(alpha: 0.60),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _joiningSpace
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          )
                        : const Text('Join'),
                  ),
                ),
              ),
            ],
          ),
          if (_joinError != null) ...[  
            const SizedBox(height: 6),
            Text(
              _joinError!,
              style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12),
            ),
          ],
          if (_joinedShares.isEmpty) ...[  
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'No joined spaces yet.',
                style: TextStyle(color: Color(0x4DFFFFFF)),
              ),
            ),
          ] else ...[  
            const SizedBox(height: 24),
            const Text(
              'JOINED SPACES',
              style: TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_joinedShares.length, (i) {
              final s = _joinedShares[i];
              final ts = (s['team_shares'] as Map<String, dynamic>?) ?? {};
              final shareName = ts['share_name']?.toString() ?? '';
              final permission = ts['permission']?.toString() ?? '';
              final shareId = (ts['share_id'] ?? s['share_id'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shareName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              permission,
                              style: const TextStyle(
                                color: Color(0x4DFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: shareId.isEmpty ? null : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SharedInventoryPage(
                                shareId: shareId,
                                shareName: shareName,
                                permission: permission,
                                api: widget.api,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171717),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: const Color(0x14FFFFFF),
                              width: 0.5,
                            ),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.20), width: 1),
        ),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Share "${widget.spaceName}"',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0x73FFFFFF),
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [Tab(text: 'Share'), Tab(text: 'Joined Spaces')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_buildShareTab(), _buildJoinedTab()],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
