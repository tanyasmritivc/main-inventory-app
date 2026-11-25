import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';

class OrganizationOrders extends StatefulWidget {
  const OrganizationOrders({
    super.key,
    required this.api,
    required this.organizationId,
  });
  final ApiClient api;
  final String organizationId;

  @override
  State<OrganizationOrders> createState() => _OrganizationOrdersState();
}

class _OrganizationOrdersState extends State<OrganizationOrders> {
  final search = TextEditingController();
  Map<String, dynamic>? result;
  Object? error;
  int offset = 0;
  int generation = 0;
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      error = null;
      result = null;
    });
    try {
      final value = await widget.api.collaboration(
        '/commerce/organizations/${widget.organizationId}/orders',
        query: {'query': query, 'offset': offset},
      );
      widget.api.assertCurrentContext();
      if (mounted && request == generation) setState(() => result = value);
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    }
  }

  Future<void> manage() async {
    try {
      widget.api.assertCurrentContext();
      final uri = Uri.https('findez.ai', '/worlds/${widget.organizationId}', {
        'view': 'orders',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open FindEZ in the browser.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open organization orders.')),
        );
      }
    }
  }

  void submitQuery(String value) {
    query = value.trim();
    offset = 0;
    load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lines = (result?['order_lines'] as List?)?.whereType<Map>() ?? [];
    final stock =
        (result?['recorded_inventory'] as List?)?.whereType<Map>() ?? [];
    final canManage = result?['can_manage'] == true;
    final firstOrder =
        result != null && lines.isEmpty && query.isEmpty && offset == 0;
    final sectionTitle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: submitQuery,
                decoration: InputDecoration(
                  hintText: 'Part, SKU or order number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: search,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.cancel_outlined),
                            onPressed: () {
                              search.clear();
                              submitQuery('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (error != null)
                _OrderPanel(
                  children: [
                    Text(describeError(error!).$1),
                    TextButton(onPressed: load, child: const Text('Try again')),
                  ],
                )
              else if (result == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (firstOrder)
                _OrderPanel(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.receipt_long_outlined, size: 28),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      canManage
                          ? 'Add your first order'
                          : 'No supplier orders yet',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canManage
                          ? 'Upload a supplier order to track what you bought. Receive items into a Space when they arrive.'
                          : 'Orders will appear here when an organization owner or admin imports one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: manage,
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        label: const Text('Import order'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Opens FindEZ in your browser',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                )
              else ...[
                if (canManage)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: manage,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Import or receive an order'),
                    ),
                  ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Recorded in Spaces', style: sectionTitle),
                  const SizedBox(height: 8),
                  if (stock.isEmpty)
                    const Text('No matching inventory records on this page.'),
                  for (final row in stock)
                    _OrderRow(
                      title: row['name'].toString(),
                      details: [row['space_name'], row['location']],
                      quantity: "${row['recorded_quantity']} recorded",
                    ),
                ],
                const SizedBox(height: 16),
                Text('Supplier order lines', style: sectionTitle),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Text('No matching order lines on this page.'),
                for (final line in lines)
                  _OrderRow(
                    title: line['name'].toString(),
                    details: [
                      line['supplier'],
                      line['order_number'],
                      line['sku'],
                    ],
                    quantity:
                        "${line['ordered']} ordered · ${line['received']} received · ${line['outstanding'] == null ? 'History only' : "${line['outstanding']} outstanding"}",
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (offset > 0)
                      TextButton(
                        onPressed: () {
                          offset -= 50;
                          load();
                        },
                        child: const Text('Previous'),
                      ),
                    if (result?['has_more'] == true)
                      TextButton(
                        onPressed: () {
                          offset += 50;
                          load();
                        },
                        child: const Text('Next'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.title,
    required this.details,
    required this.quantity,
  });
  final String title;
  final List<Object?> details;
  final String quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = details
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _OrderPanel(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              metadata,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(quantity, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
