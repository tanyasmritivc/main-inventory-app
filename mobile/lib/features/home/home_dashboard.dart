import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/pending_captures.dart';
import '../../core/ui/visual_surfaces.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/world_views.dart';
import 'home_metrics.dart';

Future<T?> _optionalRead<T>(Future<T> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return null;
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.api,
    required this.workspaceName,
    this.workspaceAvailable = true,
    required this.refreshToken,
    required this.onAsk,
    required this.onDecision,
    required this.onPlace,
    required this.onAllPlaces,
    required this.onWorkspace,
    required this.onCapture,
    required this.onImport,
    required this.onWorkspaces,
  });

  final ApiClient api;
  final String workspaceName;
  final bool workspaceAvailable;
  final int refreshToken;
  final VoidCallback onAsk;
  final void Function(int index) onDecision;
  final void Function(
    String name,
    String? spaceId,
    List<InventoryItem> items,
    Map<String, int> thresholds,
  )
  onPlace;
  final VoidCallback onAllPlaces;
  final VoidCallback onWorkspace;
  final VoidCallback onCapture;
  final VoidCallback onImport;
  final VoidCallback onWorkspaces;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  _HomeData? _data;
  String? _error;
  bool _loading = true;
  ErrorKind? _errorKind;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final itemsFuture = widget.api.searchItems(query: '');
      final spacesFuture = _optionalRead(widget.api.listSpaces);
      final checkoutsFuture = _optionalRead(widget.api.getActiveCheckouts);
      final kitsFuture = _optionalRead(() async {
        final kits = await widget.api.getProjectKits();
        return Future.wait(kits.map((kit) => widget.api.getProjectKit(kit.id)));
      });
      final items = (await itemsFuture).items;
      final spaces = await spacesFuture ?? const <Map<String, dynamic>>[];
      final checkouts = await checkoutsFuture;
      final details = await kitsFuture;
      final thresholds = {
        for (final item in items)
          if (item.reorderPoint != null && item.reorderPoint! > 0)
            item.itemId: item.reorderPoint!,
      };
      if (!mounted) return;
      setState(() {
        _data = _HomeData(
          items,
          spaces,
          checkouts ?? const <Map<String, dynamic>>[],
          thresholds,
          details ?? const <ProjectKitDetail>[],
          showRunningLow: items.every((item) => item.reorderPointAvailable),
          showMissing: details != null,
          showLentOut: checkouts != null,
        );
        _loading = false;
        _errorKind = null;
      });
    } catch (error) {
      if (!mounted) return;
      var pendingCount = 0;
      try {
        pendingCount = (await PendingCaptures.list(
          widget.api.captureScopeId,
        )).length;
      } catch (_) {
        pendingCount = 0;
      }
      if (!mounted) return;
      setState(() {
        _error = describeError(error).$1;
        _errorKind = describeError(error).$2;
        _pendingCount = pendingCount;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final data = _data;
    final featuredPlaces =
        data?.places.take(3).toList() ?? const <_HomePlace>[];
    final recentItems = data?.recentItems ?? const <InventoryItem>[];
    final hasDecisions =
        data != null &&
        (data.metrics.needsIdentifying > 0 ||
            (data.showRunningLow && data.metrics.runningLow > 0) ||
            (data.showMissing && data.metrics.missing > 0) ||
            (data.showLentOut && data.metrics.lentOut > 0));
    return SafeArea(
      top: true,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextButton(
              onPressed: widget.workspaceAvailable ? widget.onWorkspace : null,
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: t.ink,
                disabledForegroundColor: t.ink,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 54),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.workspaceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineMedium,
                    ),
                  ),
                  if (widget.workspaceAvailable) ...[
                    const SizedBox(width: 8),
                    Text('⌄', style: text.headlineMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading && data == null)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              GroupedSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorKind == ErrorKind.offline
                          ? 'No connection'
                          : 'Home could not load',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorKind == ErrorKind.offline
                          ? '$_pendingCount ${_pendingCount == 1 ? 'photo is' : 'photos are'} waiting to send. Your photos remain on this phone.'
                          : _error!,
                      style: text.bodyMedium,
                    ),
                    if (_errorKind == ErrorKind.offline)
                      TextButton(
                        onPressed: widget.onCapture,
                        child: const Text('Open Capture'),
                      ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (data != null && data.items.isEmpty) ...[
              const SizedBox(height: 36),
              Text('No objects yet', style: text.headlineLarge),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onCapture,
                child: const Text('Take a photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: widget.onImport,
                child: const Text('Import a list'),
              ),
            ] else if (data != null) ...[
              if (hasDecisions) ...[
                Column(
                  children: [
                    if (data.metrics.needsIdentifying > 0)
                      _decision(
                        0,
                        data.metrics.needsIdentifying,
                        'to identify',
                        t.accent,
                      ),
                    if (data.showRunningLow && data.metrics.runningLow > 0)
                      _decision(
                        1,
                        data.metrics.runningLow,
                        'running low',
                        t.warn,
                      ),
                    if (data.showMissing && data.metrics.missing > 0)
                      _decision(2, data.metrics.missing, 'missing', t.ink),
                    if (data.showLentOut && data.metrics.lentOut > 0)
                      _decision(3, data.metrics.lentOut, 'lent out', t.ink),
                  ],
                ),
                const SizedBox(height: 26),
              ],
              if (recentItems.isNotEmpty) ...[
                _sectionTitle('Recent objects'),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < recentItems.length;
                      index++
                    ) ...[
                      if (index > 0) Divider(height: 1, color: t.separator),
                      WorldRow(
                        title: recentItems[index].displayName,
                        subtitle: recentItems[index].location,
                        count: '${recentItems[index].quantity}',
                        showCrop: true,
                        imageUrl: recentItems[index].imageUrl,
                        onTap: () async {
                          final item = recentItems[index];
                          await showItemDetailSheet(
                            context,
                            item: item,
                            api: widget.api,
                            spaceName: item.location,
                          );
                          if (mounted) unawaited(_load());
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 26),
              ],
              _sectionTitle('Places'),
              const SizedBox(height: 8),
              if (featuredPlaces.isEmpty)
                _empty('No places yet')
              else
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < featuredPlaces.length;
                      index++
                    ) ...[
                      if (index > 0) Divider(height: 1, color: t.separator),
                      _placeRow(featuredPlaces[index], data),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String value) => Text(
    value,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppTokens.of(context).text2,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _empty(String message) => GroupedSurface(
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _decision(int index, int count, String label, Color color) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$count $label',
      child: InkWell(
        onTap: () => widget.onDecision(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Text(
                '$count',
                style: text.headlineMedium?.copyWith(
                  color: color,
                  fontFamily: 'IBM Plex Mono',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: text.bodyLarge)),
              Icon(Icons.chevron_right, color: t.text2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeRow(_HomePlace place, _HomeData data) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      label: '${place.name}, ${place.count} objects',
      child: InkWell(
        onTap: () =>
            widget.onPlace(place.name, place.id, data.items, data.thresholds),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(place.name)),
                Text(
                  '${place.count}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: t.text2,
                    fontFamily: 'IBM Plex Mono',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePlace {
  const _HomePlace(this.name, this.id, this.count);
  final String name;
  final String? id;
  final int count;
}

class _HomeData {
  _HomeData(
    this.items,
    this.spaces,
    this.checkouts,
    this.thresholds,
    this.kits, {
    required this.showRunningLow,
    required this.showMissing,
    required this.showLentOut,
  });

  final List<InventoryItem> items;
  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> checkouts;
  final Map<String, int> thresholds;
  final List<ProjectKitDetail> kits;
  final bool showRunningLow;
  final bool showMissing;
  final bool showLentOut;

  HomeMetrics get metrics => HomeMetrics(
    items: items,
    thresholds: thresholds,
    kits: kits,
    checkouts: checkouts,
  );

  List<InventoryItem> get recentItems {
    final recent = List<InventoryItem>.of(items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recent.take(3).toList();
  }

  List<_HomePlace> get places {
    final result = <_HomePlace>[];
    final seen = <String>{};
    for (final space in spaces) {
      final name = (space['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final id = space['id']?.toString();
      final count = items
          .where((item) => item.location.toLowerCase() == name.toLowerCase())
          .length;
      result.add(_HomePlace(name, id, count));
      seen.add(name.toLowerCase());
    }
    for (final item in items) {
      final name = item.location.trim().isEmpty
          ? 'Unsorted'
          : item.location.trim();
      if (seen.add(name.toLowerCase())) {
        result.add(
          _HomePlace(
            name,
            null,
            items
                .where(
                  (candidate) =>
                      candidate.location.toLowerCase() == name.toLowerCase(),
                )
                .length,
          ),
        );
      }
    }
    return result..sort((a, b) => b.count.compareTo(a.count));
  }
}
