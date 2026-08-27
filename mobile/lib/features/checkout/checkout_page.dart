import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class CheckoutPage extends StatefulWidget {
  final ApiClient api;
  const CheckoutPage({required this.api, super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<Map<String, dynamic>> _checkouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final checkouts = await widget.api.getActiveCheckouts();
      if (!mounted) return;
      setState(() {
        _checkouts = checkouts;
        _loading = false;
      });
    } catch (e, stack) {
      if (mounted) setState(() => _loading = false);
      debugPrint('[CheckOut] API call failed: $e');
      debugPrint('[CheckOut] Stack: $stack');
    }
  }

  Future<void> _returnItem(String checkoutId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: Text('Return Item', style: TextStyle(color: AppTheme.textPrimary(ctx))),
        content: Text(
          'Mark "$itemName" as returned?',
          style: TextStyle(color: AppTheme.textSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Return', style: TextStyle(color: AppTheme.textPrimary(ctx), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.returnItem(checkoutId: checkoutId);
      unawaited(_load());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$itemName returned')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to return item. Try again.')),
        );
      }
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF0A84FF), const Color(0xFF30D158),
      const Color(0xFFFF9F0A), const Color(0xFFFF375F),
      const Color(0xFFBF5AF2), const Color(0xFF5E5CE6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  bool _isOverdue(String? dueBackAt) {
    if (dueBackAt == null) return false;
    final dt = DateTime.tryParse(dueBackAt);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Check-Out Tracker',
          style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: AppTheme.textSecondary(context), size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.textPrimary(context)))
          : _checkouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF30D158), size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Nothing checked out',
                        style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check out items from any item\'s detail view.',
                        style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Items checked out from shared spaces\nwill appear here for all team members.',
                        style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.textPrimary(context),
                  backgroundColor: AppTheme.surface2(context),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, color: AppTheme.textSecondary(context), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_checkouts.length} item${_checkouts.length != 1 ? 's' : ''} checked out across your team',
                              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...() {
                        final myCheckouts = _checkouts.where((c) => c['from_teammate'] != true).toList();
                        final teamCheckouts = _checkouts.where((c) => c['from_teammate'] == true).toList();
                        return [
                          if (myCheckouts.isNotEmpty) ...[_buildSectionHeader('MY CHECKOUTS'), ...myCheckouts.map(_buildCheckoutCard)],
                          if (teamCheckouts.isNotEmpty) ...[_buildSectionHeader('TEAM CHECKOUTS'), ...teamCheckouts.map(_buildCheckoutCard)],
                        ];
                      }(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0x4DFFFFFF),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _buildCheckoutCard(Map<String, dynamic> checkout) {
    final itemData = checkout['items'] as Map<String, dynamic>? ?? {};
    final itemName = itemData['name'] as String? ?? 'Unknown item';
    final location = (checkout['space_name'] as String?)?.isNotEmpty == true
        ? checkout['space_name'] as String
        : (itemData['location'] as String? ?? '');
    final checkedOutBy = checkout['checked_out_by'] as String? ?? '';
    final checkedOutAt = checkout['checked_out_at'] as String?;
    final dueBackAt = checkout['due_back_at'] as String?;
    final checkoutId = checkout['checkout_id'] as String? ?? '';
    final overdue = _isOverdue(dueBackAt);
    final isTeammate = checkout['from_teammate'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overdue ? const Color(0x0AEF4444) : AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue ? const Color(0x33EF4444) : AppTheme.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _avatarColor(checkedOutBy),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                checkedOutBy.isNotEmpty ? checkedOutBy[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Checked out by $checkedOutBy · ${_timeAgo(checkedOutAt)}',
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Color(0x73FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (isTeammate)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '👥 From shared space',
                      style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 11),
                    ),
                  ),
                if (dueBackAt != null)
                  Text(
                    overdue
                        ? '⚠ Overdue — was due ${_timeAgo(dueBackAt)}'
                        : 'Due back ${_timeAgo(dueBackAt)}',
                    style: TextStyle(
                      color: overdue ? const Color(0xFFEF4444) : const Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _returnItem(checkoutId, itemName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Text(
                'Return',
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
