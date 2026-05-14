import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';

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
  String _permission = 'view';
  bool _loading = false;
  String? _createdCode;
  List<dynamic> _myShares = [];
  List<dynamic> _joinedShares = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadShares();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    try {
      final my = await widget.api.getMyShares();
      final joined = await widget.api.getJoinedShares();
      if (mounted) setState(() { _myShares = my; _joinedShares = joined; });
    } catch (_) {}
  }

  Future<void> _generateCode() async {
    setState(() => _loading = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revokeShare(String shareId) async {
    try {
      await widget.api.deleteShare(shareId);
      await _loadShares();
    } catch (_) {}
  }

  Widget _permChip(String value, String label) {
    final selected = _permission == value;
    return GestureDetector(
      onTap: () => setState(() => _permission = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x40FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _generateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Generate Code',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
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
                    color: const Color(0x0AFFFFFF),
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
                color: const Color(0x0AFFFFFF),
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
                                    s['code']?.toString() ?? '',
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

  Widget _buildJoinedTab() {
    if (_joinedShares.isEmpty) {
      return const Center(
        child: Text(
          'No joined spaces yet.',
          style: TextStyle(color: Color(0x4DFFFFFF)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _joinedShares.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = _joinedShares[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
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
                      s['share_name']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${s['owner']?.toString() ?? ''} · '
                      '${s['permission']?.toString() ?? ''}',
                      style: const TextStyle(
                        color: Color(0x4DFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
    );
  }
}
