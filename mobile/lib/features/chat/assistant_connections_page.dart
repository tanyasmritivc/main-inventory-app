import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/external_links.dart';
import '../../core/api_client.dart';
import '../scan/connector_destination_page.dart';

/// Existing outbound assistant setup. No inferred connection or OAuth status.
class AssistantConnectionsPage extends StatefulWidget {
  const AssistantConnectionsPage({super.key, this.api});
  final ApiClient? api;
  @override
  State<AssistantConnectionsPage> createState() =>
      _AssistantConnectionsPageState();
}

class _AssistantConnectionsPageState extends State<AssistantConnectionsPage> {
  String query = '';
  Future<void> _open(String path) async {
    final ok = await tryOpenExternalUrl(Uri.parse('https://findez.ai$path'));
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open FindEZ. Please try again.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connections')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          onChanged: (value) =>
              setState(() => query = value.toLowerCase().trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.search),
            hintText: 'Search connections',
          ),
        ),
        const SizedBox(height: 20),
        if (widget.api != null) ...[
          const Text('Import sources', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          for (final entry in const [
            (
              'CSV & Excel',
              'Map columns and review inventory',
              'inventory',
              Icons.table_chart_outlined,
            ),
            (
              'Parts lists',
              'KiCad and Fusion BOM files',
              'bom',
              Icons.precision_manufacturing_outlined,
            ),
          ])
            if ('${entry.$1} ${entry.$2}'.toLowerCase().contains(query))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(entry.$4, size: 22),
                  title: Text(entry.$1),
                  subtitle: Text(entry.$2),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConnectorDestinationPage(
                        api: widget.api!,
                        kind: entry.$3,
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 20),
        ],
        const Text('AI assistants', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        for (final entry in const [
          (
            'Claude Desktop',
            'MCP extension',
            'Install the FindEZ desktop extension on your computer, then add a scoped API key.',
          ),
          (
            'ChatGPT',
            'Actions',
            'Add FindEZ Actions to your GPT using the existing schema and a scoped API key.',
          ),
        ])
          if ('${entry.$1} ${entry.$2}'.toLowerCase().contains(query))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(CupertinoIcons.chat_bubble_2, size: 22),
                title: Text(entry.$1),
                subtitle: Text('${entry.$2} · Setup on web'),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (sheetContext) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(entry.$3),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _open('/docs/api#ai-assistants'),
                            icon: const Icon(
                              CupertinoIcons.arrow_up_right,
                              size: 16,
                            ),
                            label: const Text('Open setup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        if (query.isNotEmpty &&
            ![
              'claude desktop mcp extension',
              'chatgpt actions',
              if (widget.api != null)
                'csv & excel map columns and review inventory',
              if (widget.api != null) 'parts lists kicad and fusion bom files',
            ].any((value) => value.contains(query)))
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No matching connections.'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _open('/settings/api-keys'),
          icon: const Icon(CupertinoIcons.lock),
          label: const Text('Manage API keys'),
        ),
      ],
    ),
  );
}
