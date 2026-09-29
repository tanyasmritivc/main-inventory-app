import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/world_views.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<ActivityEntry>? _events;
  String? _error;
  String _filter = 'Everything';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final events = await widget.api.getRecentActivity(limit: 100);
      if (!mounted) return;
      setState(() {
        _events = events;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  bool _isCorrection(ActivityEntry event) {
    final type = (event.eventType ?? '').toLowerCase();
    return type.contains('correct') ||
        type.contains('review') ||
        type.contains('identity');
  }

  bool _isFindEz(ActivityEntry event) {
    final type = (event.eventType ?? '').toLowerCase();
    return type == 'ai_chat' ||
        type == 'photo_scan' ||
        type == 'find_match' ||
        type.startsWith('auto_');
  }

  bool _matches(ActivityEntry event) => switch (_filter) {
    'People' =>
      !_isCorrection(event) &&
          !_isFindEz(event) &&
          (event.userId?.isNotEmpty ?? false),
    'FindEZ' => _isFindEz(event),
    'Corrections' => _isCorrection(event),
    _ => true,
  };

  String _dateHeading(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _type(ActivityEntry event) {
    if (_isCorrection(event)) return 'Correction';
    if (_isFindEz(event)) return 'FindEZ';
    return 'Update';
  }

  Future<void> _openObject(ActivityEntry event) async {
    final itemId = event.metadata['item_id']?.toString() ?? '';
    if (itemId.isEmpty) return;
    try {
      final item = await widget.api.itemDetail(itemId);
      if (!mounted) return;
      await showItemDetailSheet(context, item: item, api: widget.api);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final events = _events?.where(_matches).toList() ?? const <ActivityEntry>[];
    final groups = <String, List<ActivityEntry>>{};
    for (final event in events) {
      groups.putIfAbsent(_dateHeading(event.createdAt), () => []).add(event);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Activity',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final label in const [
                      'Everything',
                      'People',
                      'FindEZ',
                      'Corrections',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == label,
                          onSelected: (_) => setState(() => _filter = label),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    if (_events == null && _error == null)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Loading activity',
                              style: TextStyle(color: t.text2),
                            ),
                          ],
                        ),
                      )
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load activity',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          _events!.isEmpty
                              ? 'No changes in this workspace yet.'
                              : 'No changes match this filter.',
                          style: TextStyle(color: t.text2, fontSize: 15),
                        ),
                      )
                    else
                      for (final group in groups.entries)
                        WorldSection(
                          title: group.key,
                          children: [
                            for (final event in group.value)
                              WorldRow(
                                title: event.summary,
                                subtitle: _type(event),
                                count: _time(event.createdAt),
                                onTap: event.metadata['item_id'] == null
                                    ? null
                                    : () => _openObject(event),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
