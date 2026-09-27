import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../projects/project_kits_page.dart';
import '../scan/scan_page.dart';
import '../sharing/shared_inventory_page.dart';
import 'item_detail_sheet.dart';

class FindPage extends StatefulWidget {
  const FindPage({
    super.key,
    required this.api,
    required this.refreshToken,
    required this.onOpenCamera,
    this.initialQuery,
    this.onRegisterOpenAssistDestination,
  });

  final ApiClient api;
  final int refreshToken;
  final ValueChanged<CaptureMode> onOpenCamera;
  final String? initialQuery;
  final void Function(Future<void> Function(Map<String, dynamic>))?
  onRegisterOpenAssistDestination;

  @override
  State<FindPage> createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  late final TextEditingController _query;
  Timer? _debounce;
  int _version = 0;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<InventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterOpenAssistDestination?.call(_openAssistDestination);
    });
    if (_query.text.trim().isNotEmpty) {
      unawaited(_search(_query.text.trim(), ++_version));
    }
  }

  @override
  void didUpdateWidget(FindPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.api != oldWidget.api) {
      setState(() {
        _items = const [];
        _searched = false;
      });
    }
    if (widget.api != oldWidget.api ||
        widget.refreshToken != oldWidget.refreshToken) {
      final query = _query.text.trim();
      if (query.isNotEmpty) unawaited(_search(query, ++_version));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    _debounce?.cancel();
    final version = ++_version;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _items = const [];
        _searched = false;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query, version),
    );
  }

  Future<void> _search(String query, int version) async {
    if (!mounted || version != _version) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.searchItems(query: query);
      if (!mounted || version != _version) return;
      setState(() {
        _items = result.items;
        _searched = true;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted && version == _version) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openAssistDestination(Map<String, dynamic> hint) async {
    if (!mounted) return;
    if ((hint['type'] ?? '').toString() == 'project_kit') {
      final id = (hint['id'] ?? '').toString().trim();
      if (id.isEmpty) return;
      try {
        final detail = await widget.api.getProjectKit(id);
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                ProjectKitDetailPage(api: widget.api, initial: detail),
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
        }
      }
      return;
    }
    final shareId = (hint['share_id'] ?? '').toString().trim();
    if (shareId.isNotEmpty) {
      final name = (hint['space_name'] ?? hint['name'] ?? '').toString().trim();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SharedInventoryPage(
            shareId: shareId,
            shareName: name,
            permission: 'view',
            api: widget.api,
          ),
        ),
      );
      return;
    }
    final query = (hint['name'] ?? hint['space_name'] ?? '').toString().trim();
    if (query.isEmpty) return;
    _query.text = query;
    await _search(query, ++_version);
  }

  String _path(InventoryItem item) {
    final path =
        [
              item.workspaceName,
              item.spaceName ?? item.location,
              item.binName,
              item.container,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .join(' / ');
    return path.isEmpty ? 'No place recorded' : path;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Text(
                'Find',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _query,
                onChanged: _queryChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'What are you looking for?',
                ),
              ),
            ),
            Expanded(child: _results(t)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                AppTokens.bottomBarClearance + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => widget.onOpenCamera(CaptureMode.see),
                    child: const Text('Point the camera at one'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => widget.onOpenCamera(CaptureMode.scan),
                    child: const Text('Scan a barcode'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Checks what you already own before you buy another.',
                    style: TextStyle(color: t.text3, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(AppTokens t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not search this workspace.',
                style: TextStyle(color: t.ink, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text2, fontSize: 14),
              ),
              TextButton(
                onPressed: () => _search(_query.text.trim(), ++_version),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Search for an object to find its place.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text2, fontSize: 15),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No matching objects in this workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text2, fontSize: 15),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      itemCount: _items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.separator),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Material(
          color: t.card,
          child: InkWell(
            onTap: () =>
                showItemDetailSheet(context, item: item, api: widget.api),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: TextStyle(
                            color: t.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.displayDescription != null)
                          Text(
                            item.displayDescription!,
                            style: TextStyle(color: t.text2, fontSize: 13),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          _path(item),
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${item.quantity}',
                    style: TextStyle(
                      color: t.ink,
                      fontFamily: 'IBMPlexMono',
                      fontSize: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
