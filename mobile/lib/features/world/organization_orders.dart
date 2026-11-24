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

  @override
  Widget build(BuildContext context) {
    final lines = (result?['order_lines'] as List?)?.whereType<Map>() ?? [];
    final stock =
        (result?['recorded_inventory'] as List?)?.whereType<Map>() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Part, SKU or order number',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                query = value.trim();
                offset = 0;
                load();
              },
            ),
            if (error != null) ...[
              Text(describeError(error!).$1),
              TextButton(onPressed: load, child: const Text('Retry')),
            ] else if (result == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (result?['can_manage'] == true)
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Import or receive an order'),
                  subtitle: const Text(
                    'Open the full order review in your browser',
                  ),
                  onTap: manage,
                ),
              if (query.isNotEmpty) ...[
                const ListTile(title: Text('Recorded in Spaces')),
                if (stock.isEmpty)
                  const Text('No matching inventory records on this page.'),
                for (final row in stock)
                  ListTile(
                    title: Text('${row['name']}'),
                    subtitle: Text(
                      '${row['recorded_quantity']} recorded · ${row['space_name']} · ${row['location'] ?? ''}',
                    ),
                  ),
              ],
              const ListTile(title: Text('Supplier order lines')),
              if (lines.isEmpty) const Text('No matching orders on this page.'),
              for (final line in lines)
                ListTile(
                  title: Text('${line['name']}'),
                  isThreeLine: true,
                  subtitle: Text(
                    "${line['supplier']} · ${line['order_number']} · ${line['sku']}\n${line['ordered']} ordered · ${line['received']} received · ${line['outstanding'] == null ? 'History only' : "${line['outstanding']} outstanding"}",
                  ),
                ),
              Wrap(
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
    );
  }
}
