import 'package:flutter/material.dart';
import '../../core/api_client.dart';

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
    setState(() => _loading = true);
    try {
      final checkouts = await widget.api.getActiveCheckouts();
      setState(() {
        _checkouts = checkouts;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      // No error shown — just empty state
    }
  }

  Future<void> _returnItem(String checkoutId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Return Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Mark "$itemName" as returned?',
          style: const TextStyle(color: Color(0x73FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0x73FFFFFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.returnItem(checkoutId: checkoutId);
      _load();
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

  bool _isOverdue(String? dueBackAt) {
    if (dueBackAt == null) return false;
    final dt = DateTime.tryParse(dueBackAt);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Check-Out Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.white70, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _checkouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF30D158), size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Nothing checked out',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check out items from any item\'s detail view.',
                        style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: Colors.white,
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x14FFFFFF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_checkouts.length} item${_checkouts.length == 1 ? '' : 's'} currently checked out',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'CURRENTLY OUT',
                          style: TextStyle(
                            color: Color(0x4DFFFFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      ..._checkouts.map((checkout) {
                        final itemData = checkout['items'] as Map<String, dynamic>? ?? {};
                        final itemName = itemData['name'] as String? ?? 'Unknown item';
                        final location = itemData['location'] as String? ?? '';
                        final checkedOutBy = checkout['checked_out_by'] as String? ?? '';
                        final checkedOutAt = checkout['checked_out_at'] as String?;
                        final dueBackAt = checkout['due_back_at'] as String?;
                        final checkoutId = checkout['checkout_id'] as String? ?? '';
                        final overdue = _isOverdue(dueBackAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: overdue
                                ? const Color(0x0AEF4444)
                                : const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: overdue
                                  ? const Color(0x33EF4444)
                                  : const Color(0x14FFFFFF),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0x14FFFFFF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    checkedOutBy.isNotEmpty
                                        ? checkedOutBy[0].toUpperCase()
                                        : '?',
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Checked out by $checkedOutBy · ${_timeAgo(checkedOutAt)}',
                                      style: const TextStyle(
                                        color: Color(0x73FFFFFF),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (location.isNotEmpty)
                                      Text(
                                        'From: $location',
                                        style: const TextStyle(
                                          color: Color(0x4DFFFFFF),
                                          fontSize: 11,
                                        ),
                                      ),
                                    if (dueBackAt != null)
                                      Text(
                                        overdue
                                            ? '⚠ Overdue — was due ${_timeAgo(dueBackAt)}'
                                            : 'Due back ${_timeAgo(dueBackAt)}',
                                        style: TextStyle(
                                          color: overdue
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFFBBF24),
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
                                    color: const Color(0x0AFFFFFF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0x14FFFFFF)),
                                  ),
                                  child: const Text(
                                    'Return',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
