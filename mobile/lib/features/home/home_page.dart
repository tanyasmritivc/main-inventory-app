import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
import '../chat/chat_page.dart';
import '../documents/documents_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    this.onOpenScan,
    this.onOpenSpaces,
    this.onInventoryMutated,
  });

  final ApiClient api;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenSpaces;
  final VoidCallback? onInventoryMutated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _ask;

  bool _uploading = false;
  String? _uploadMessage;
  String? _uploadError;

  bool _loading = true;
  bool _isRefreshing = false;
  String? _error;

  List<ActivityEntry> _activities = const [];
  List<InventoryItem> _items = const [];
  Map<String, int> _thresholds = const {};

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      final t = error.type;
      if (t == dio.DioExceptionType.connectionTimeout ||
          t == dio.DioExceptionType.sendTimeout ||
          t == dio.DioExceptionType.receiveTimeout) {
        return 'That took longer than expected. Try again.';
      }
    }
    return 'That didn’t work. Try again.';
  }

  @override
  void initState() {
    super.initState();
    _ask = TextEditingController();

    final cached = InventoryCache.items;
    if (cached.isNotEmpty) {
      _items = cached;
      _loading = false;
    }

    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadItemsAndThresholds(),
        _loadActivity(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        _loadItemsAndThresholds(),
        _loadActivity(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyRequestError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openChat({String? message}) async {
    final m = (message ?? '').trim();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          api: widget.api,
          initialMessage: m.isEmpty ? null : m,
          onInventoryMutated: () {
            widget.onInventoryMutated?.call();
            unawaited(_loadAll());
          },
        ),
      ),
    );
  }

  Future<void> _quickAddItem() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Unsorted');
    final location = TextEditingController(text: 'Unsorted');
    final quantity = TextEditingController(text: '1');
    final threshold = TextEditingController();

    try {
      final out = await showModalBottomSheet<_QuickAddPayload>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final bottom = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add item',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: threshold,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low stock threshold (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final n = name.text.trim();
                    if (n.isEmpty) return;
                    final c = category.text.trim().isEmpty
                        ? 'Unsorted'
                        : category.text.trim();
                    final loc = location.text.trim().isEmpty
                        ? 'Unsorted'
                        : location.text.trim();
                    final qty = int.tryParse(quantity.text.trim()) ?? 1;
                    final thrRaw = int.tryParse(threshold.text.trim());
                    final thr = (thrRaw != null && thrRaw > 0) ? thrRaw : null;

                    Navigator.of(context).pop(
                      _QuickAddPayload(
                        item: AddItemRequest(
                          name: n,
                          category: c,
                          quantity: qty <= 0 ? 1 : qty,
                          location: loc,
                        ),
                        threshold: thr,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      );

      if (out == null) return;

      final created = await widget.api.addItem(item: out.item);
      if (out.threshold != null && out.threshold! > 0) {
        await LowStockPrefs.setThreshold(
          itemId: created.itemId,
          threshold: out.threshold,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+1 item added')),
      );
      widget.onInventoryMutated?.call();
      unawaited(_loadAll());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRequestError(e))),
      );
    } finally {
      name.dispose();
      category.dispose();
      location.dispose();
      quantity.dispose();
      threshold.dispose();
    }
  }

  Future<void> _loadActivity() async {
    try {
      final items = await widget.api.getRecentActivity(limit: 10);
      if (!mounted) return;
      setState(() => _activities = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    }
  }

  Future<void> _loadItemsAndThresholds() async {
    try {
      final thresholds = await LowStockPrefs.loadAll();
      if (mounted) {
        setState(() => _thresholds = thresholds);
      }

      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;

      final resp = await supabase
          .from('items')
          .select('item_id,name,category,quantity,location,image_url,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(250);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();
      InventoryCache.setItems(items);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    }
  }

  ({int totalQuantity, int totalTypes}) _weeklyStats() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var quantitySum = 0;
    var typeCount = 0;
    for (final it in _items) {
      if (it.createdAt.isAfter(cutoff)) {
        quantitySum += (it.quantity <= 0 ? 0 : it.quantity);
        typeCount++;
      }
    }
    return (totalQuantity: quantitySum, totalTypes: typeCount);
  }

  int _lowStockCount() {
    if (_thresholds.isEmpty || _items.isEmpty) return 0;
    var n = 0;
    for (final it in _items) {
      final thr = _thresholds[it.itemId];
      if (thr == null || thr <= 0) continue;
      if (it.quantity <= thr) n++;
    }
    return n;
  }

  String _mostActiveLocation() {
    if (_items.isEmpty) return '—';
    final counts = <String, int>{};
    for (final it in _items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      counts[loc] = (counts[loc] ?? 0) + (it.quantity <= 0 ? 0 : it.quantity);
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return '—';
    return entries.first.key;
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _pickAndUpload() async {
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _uploadMessage = null;
      _uploadError = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      final file = picked?.files.single;
      if (file == null) return;
      if (file.bytes == null) throw Exception('Unable to read file bytes');

      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };

      final mf = dio.MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: MediaType.parse(mime),
      );

      final res = await widget.api.uploadDocument(file: mf);
      if (!mounted) return;
      setState(() => _uploadMessage = res.activitySummary.isNotEmpty ? res.activitySummary : 'Uploaded ${res.filename}');
      await _loadAll();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = _friendlyRequestError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = _friendlyRequestError(e));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF020617),
        Color(0xFF0F172A),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    const accent = LinearGradient(
      colors: [
        Color(0xFF5EEAD4),
        Color(0xFF60A5FA),
        Color(0xFFC084FC),
        Color(0xFFF472B6),
        Color(0xFFFCA5A5),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final overlay = Colors.white.withValues(alpha: 0.06);
    final weeklyStats = _weeklyStats();
    final lowCount = _lowStockCount();
    final mostActive = _mostActiveLocation();
    final recent = _items.take(12).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DocumentsPage(api: widget.api),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ask,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) {
                          final q = v.trim();
                          if (q.isEmpty) return;
                          _ask.clear();
                          unawaited(_openChat(message: q));
                        },
                        decoration: const InputDecoration(
                          hintText: 'Ask anything about your stuff...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: PrimaryGradientButton(
                        borderRadius: 18,
                        onPressed: () {
                          final q = _ask.text.trim();
                          if (q.isEmpty) return;
                          _ask.clear();
                          unawaited(_openChat(message: q));
                        },
                        child: const Text('Ask'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            if (_error != null)
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Text(
              'Insights',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InsightRow(
                    title: weeklyStats.totalQuantity == 0 && weeklyStats.totalTypes == 0
                        ? 'No items added'
                        : '${weeklyStats.totalQuantity}',
                    value: weeklyStats.totalQuantity == 0 && weeklyStats.totalTypes == 0
                        ? ''
                        : 'items across',
                    subtitle: weeklyStats.totalQuantity == 0 && weeklyStats.totalTypes == 0
                        ? 'this week'
                        : '${weeklyStats.totalTypes} types',
                    icon: Icons.add_box_outlined,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _InsightRow(
                    title: 'Low on',
                    value: '$lowCount',
                    subtitle: 'items',
                    icon: Icons.error_outline_rounded,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _InsightRow(
                    title: 'Most active',
                    value: mostActive,
                    subtitle: 'location',
                    icon: Icons.place_outlined,
                    accent: accent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Quick actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: widget.onOpenScan,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: overlay,
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: null, // Disable built-in ripple; InkWell handles tap
                              icon: ShaderMask(
                                shaderCallback: (rect) => accent.createShader(rect),
                                blendMode: BlendMode.srcIn,
                                child:
                                    const Icon(Icons.center_focus_strong_outlined),
                              ),
                              label: const Text('Scan Item'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _quickAddItem,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: overlay,
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: null, // Disable built-in ripple; InkWell handles tap
                              icon: ShaderMask(
                                shaderCallback: (rect) => accent.createShader(rect),
                                blendMode: BlendMode.srcIn,
                                child: const Icon(Icons.add),
                              ),
                              label: const Text('Add Item'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryGradientButton(
                      onPressed: () => unawaited(_openChat()),
                      child: const Text('Open Assist'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: overlay,
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _uploading ? null : _pickAndUpload,
                        child: Text(
                          _uploading ? 'Uploading…' : 'Upload a document',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            if (_uploadMessage != null)
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: 16,
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_uploadError != null)
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadError!,
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Text(
              'Recently added',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 104,
              child: recent.isEmpty
                  ? GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: Text(
                          _loading
                              ? 'Loading…'
                              : 'No items yet. Try scanning something.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final it = recent[index];
                        final loc = it.location.trim().isEmpty
                            ? 'Unsorted'
                            : it.location.trim();
                        return SizedBox(
                          width: 220,
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Qty ${it.quantity} · $loc',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),
            Text(
              'Recent activity',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: _activities.isEmpty
                  ? const GlassCard(
                      child: Center(child: Text('No activity yet.')),
                    )
                  : GlassCard(
                      padding: const EdgeInsets.all(6),
                      child: ListView.separated(
                        itemCount: _activities.take(8).length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final a = _activities[index];
                          return ListTile(
                            dense: true,
                            title: Text(a.summary),
                            subtitle: Text(
                              a.createdAt.toLocal().toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final LinearGradient accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (rect) => accent.createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Icon(icon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title $value',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAddPayload {
  const _QuickAddPayload({required this.item, required this.threshold});

  final AddItemRequest item;
  final int? threshold;
}
