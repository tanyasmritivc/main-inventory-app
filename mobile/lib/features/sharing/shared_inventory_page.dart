import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

class SharedInventoryPage extends StatefulWidget {
  const SharedInventoryPage({
    super.key,
    required this.shareId,
    required this.shareName,
    required this.permission,
  });

  final String shareId;
  final String shareName;
  final String permission;

  @override
  State<SharedInventoryPage> createState() => _SharedInventoryPageState();
}

class _SharedInventoryPageState extends State<SharedInventoryPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _backend()
          .get<dynamic>('/sharing/${widget.shareId}/inventory');
      if (!mounted) return;
      setState(() {
        _items = (res.data as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<String> _sortedCategoryPills() {
    final cats = <String>{};
    for (final it in _items) {
      final c = (it['category'] ?? '').toString().trim();
      cats.add(c.isEmpty ? 'Uncategorized' : c);
    }
    return ['All', ...cats.toList()..sort()];
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (item['name'] ?? '').toString().toLowerCase().contains(q) ||
        (item['brand'] ?? '').toString().toLowerCase().contains(q) ||
        (item['category'] ?? '').toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.shareName,
          style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.permission == 'view'
                  ? 'Read only · Shared inventory'
                  : 'Can edit · Shared inventory',
              style: const TextStyle(
                  color: Color(0x73FFFFFF), fontSize: 12),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.permission == 'view')
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.visibility_outlined,
                            size: 16, color: Color(0x73FFFFFF)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "You're viewing a shared inventory",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                              Text(
                                'Contact the owner to make changes.',
                                style: TextStyle(
                                    color: Color(0x73FFFFFF), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: SizedBox(
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0x14FFFFFF), width: 0.5),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: Color(0x4DFFFFFF), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search in this space...',
                                  hintStyle: TextStyle(
                                      color: Color(0x33FFFFFF),
                                      fontSize: 14),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                  FocusScope.of(context).unfocus();
                                },
                                child: const Icon(Icons.close,
                                    color: Color(0x4DFFFFFF), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemCount: _sortedCategoryPills().length,
                      itemBuilder: (_, i) {
                        final pills = _sortedCategoryPills();
                        final label = pills[i];
                        final isActive = _selectedCategory == label;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color: const Color(0x14FFFFFF),
                                      width: 0.5),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : const Color(0x73FFFFFF),
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No items in this shared inventory.',
          style: TextStyle(color: Color(0x4DFFFFFF)),
        ),
      );
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat =
          (item['category'] ?? '').toString().trim();
      final key = cat.isEmpty ? 'Uncategorized' : cat;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedCats = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final displayedCats = _selectedCategory == 'All'
        ? sortedCats
        : sortedCats.where((c) => c == _selectedCategory).toList();

    final filteredGroups = <String, List<Map<String, dynamic>>>{};
    for (final cat in displayedCats) {
      final matches =
          (groups[cat] ?? []).where(_matchesSearch).toList();
      if (matches.isNotEmpty) filteredGroups[cat] = matches;
    }
    final filteredCats =
        displayedCats.where((c) => filteredGroups.containsKey(c)).toList();

    if (filteredCats.isEmpty && _searchQuery.trim().isNotEmpty) {
      return const Center(
        child: Text(
          'No items match your search',
          style: TextStyle(color: Color(0x4DFFFFFF)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final cat in filteredCats) ...[
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
            child: Text(
              cat.toUpperCase(),
              style: const TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0x14FFFFFF), width: 0.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                for (int i = 0;
                    i < filteredGroups[cat]!.length;
                    i++) ...[
                  _buildItemRow(filteredGroups[cat]![i]),
                  if (i < filteredGroups[cat]!.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0x14FFFFFF),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final qty = item['quantity']?.toString() ?? '0';
    final location = (item['location'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    location,
                    style: const TextStyle(
                        color: Color(0x4DFFFFFF), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'Qty $qty',
            style: const TextStyle(
                color: Color(0x4DFFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
