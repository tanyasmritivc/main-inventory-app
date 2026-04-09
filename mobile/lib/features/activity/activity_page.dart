import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _loading = true;
  String? _error;
  List<ActivityEntry> _activities = const [];

  static const _bgGradient = LinearGradient(
    colors: [
      Color(0xFF020617),
      Color(0xFF0F172A),
      Color(0xFF020617),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.api.getRecentActivity(limit: 50);
      if (!mounted) return;
      setState(() {
        _activities = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load activity';
        _loading = false;
      });
    }
  }

  IconData _iconFor(ActivityEntry a) {
    final s = a.summary.toLowerCase();
    if (s.contains('scan')) return Icons.center_focus_strong_outlined;
    if (s.contains('upload') || s.contains('document')) {
      return Icons.description_outlined;
    }
    if (s.contains('add') || s.contains('created')) return Icons.add_circle_outline;
    if (s.contains('delete') || s.contains('removed')) return Icons.delete_outline;
    return Icons.timeline;
  }

  String _titleFor(ActivityEntry a) {
    final s = a.summary.trim();
    if (s.isNotEmpty) return s;
    return 'Activity';
  }

  String _timeAgo(DateTime t) {
    final now = DateTime.now();
    var d = now.difference(t);
    if (d.isNegative) d = Duration.zero;

    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final weeks = (d.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (d.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (d.inDays / 365).floor();
    return '${years}y ago';
  }

  Widget _loadingBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        GlassCard(
          padding: EdgeInsets.all(6),
          child: Column(
            children: [
              SkeletonListTile(),
              Divider(height: 1),
              SkeletonListTile(),
              Divider(height: 1),
              SkeletonListTile(),
              Divider(height: 1),
              SkeletonListTile(),
              Divider(height: 1),
              SkeletonListTile(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyBody() {
    final t1 = Theme.of(context).textTheme.titleMedium;
    final t2 = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('No activity yet', style: t1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Start by scanning or adding items',
                style: t2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBody() {
    final t = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.78),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_error ?? 'Could not load activity', style: t, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.92),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activities.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final a = _activities[index];
              return ListTile(
                dense: true,
                leading: Icon(_iconFor(a), color: Colors.white.withValues(alpha: 0.80)),
                title: Text(_titleFor(a)),
                subtitle: Text(_timeAgo(a.createdAt)),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = _loadingBody();
    } else if (_error != null) {
      body = _errorBody();
    } else if (_activities.isEmpty) {
      body = _emptyBody();
    } else {
      body = _listBody();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: body,
      ),
    );
  }
}
