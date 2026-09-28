import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/pending_captures.dart';
import '../../core/ui/visual_surfaces.dart';
import '../showcase/tutorial_controller.dart';
import '../inventory/item_detail_sheet.dart';
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
    return SafeArea(
      top: true,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
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
                  Text(widget.workspaceName, style: text.headlineMedium),
                  if (widget.workspaceAvailable) ...[
                    const SizedBox(width: 8),
                    Text('⌄', style: text.headlineMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            GroupedSurface(
              padding: EdgeInsets.zero,
              child: InkWell(
                key: TutorialController.homeAskKey,
                onTap: widget.onAsk,
                child: SizedBox(
                  height: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ask about your inventory',
                        style: text.bodyLarge?.copyWith(color: t.text2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
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
              Text('Nothing here yet.', style: text.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'One photograph changes that.',
                style: text.bodyLarge?.copyWith(color: t.text2),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onCapture,
                child: const Text('Photograph something'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: widget.onImport,
                child: const Text('Import a list'),
              ),
              const SizedBox(height: 10),
              if (widget.workspaceAvailable)
                OutlinedButton(
                  onPressed: widget.onWorkspaces,
                  child: const Text('Choose a workspace'),
                ),
            ] else if (data != null) ...[
              _sectionTitle('Needs a decision'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.52,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _decision(
                    0,
                    data.metrics.needsIdentifying,
                    'need identifying',
                    t.accent,
                  ),
                  if (data.showRunningLow)
                    _decision(
                      1,
                      data.metrics.runningLow,
                      'running low',
                      t.warn,
                    ),
                  if (data.showMissing)
                    _decision(2, data.metrics.missing, 'missing', t.ink),
                  if (data.showLentOut)
                    _decision(3, data.metrics.lentOut, 'lent out', t.ink),
                ],
              ),
              const SizedBox(height: 26),
              _sectionTitle('Captured today'),
              const SizedBox(height: 10),
              if (data.capturedToday.isEmpty)
                _empty(
                  'Nothing captured today. Your new objects will appear here.',
                )
              else
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.capturedToday.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final item = data.capturedToday[index];
                      return InkWell(
                        onTap: () async {
                          await showItemDetailSheet(
                            context,
                            item: item,
                            api: widget.api,
                            spaceName: item.location,
                          );
                          if (mounted) unawaited(_load());
                        },
                        child: SizedBox(
                          width: 112,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ColoredBox(
                                  color: t.card,
                                  child: SizedBox(
                                    height: 94,
                                    width: 112,
                                    child: item.imageUrl?.isNotEmpty == true
                                        ? Image.network(
                                            item.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Center(
                                                  child: Text('No photo'),
                                                ),
                                          )
                                        : Center(
                                            child: Text(
                                              item.quantity.toString(),
                                              style: text.headlineMedium,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(child: _sectionTitle('Where things live')),
                  TextButton(
                    onPressed: widget.onAllPlaces,
                    child: const Text('All places'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.places.isEmpty)
                _empty('No places yet. Add a place to organize what you own.')
              else
                GroupedSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < data.places.length;
                        index++
                      ) ...[
                        if (index > 0) Divider(height: 1, color: t.separator),
                        _placeRow(data.places[index], data),
                      ],
                    ],
                  ),
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
      child: GroupedSurface(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => widget.onDecision(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: text.headlineLarge?.copyWith(
                    color: color,
                    fontFamily: 'IBM Plex Mono',
                  ),
                ),
                const SizedBox(height: 5),
                Text(label, style: text.bodySmall?.copyWith(color: t.text2)),
              ],
            ),
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
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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

  List<InventoryItem> get capturedToday {
    final now = DateTime.now();
    return items.where((item) {
      final date = item.createdAt.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    return result;
  }
}
