import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/external_links.dart';
import '../../core/api_client.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/utility_page.dart';
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
  Widget build(BuildContext context) => UtilityPage(
    title: 'Connections',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const UtilityHint(
          'Import files or set up FindEZ with an AI assistant.',
        ),
        const SizedBox(height: 16),
        TextField(
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (value) =>
              setState(() => query = value.toLowerCase().trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.search, size: 18),
            hintText: 'Search connections',
          ),
        ),
        const SizedBox(height: 20),
        if (widget.api != null) ...[
          const UtilitySection('Import sources'),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: UtilityCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Icon(entry.$4, size: 22),
                    title: AppText(
                      entry.$1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: UtilityHint(entry.$2),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
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
              ),
          const SizedBox(height: 8),
        ],
        const UtilitySection('AI assistants'),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: UtilityCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(CupertinoIcons.chat_bubble_2, size: 22),
                  title: AppText(
                    entry.$1,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: UtilityHint('${entry.$2} · Setup on web'),
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
            ),
        if (query.isNotEmpty &&
            ![
              'claude desktop mcp extension',
              'chatgpt actions',
              if (widget.api != null)
                'csv & excel map columns and review inventory',
              if (widget.api != null) 'parts lists kicad and fusion bom files',
            ].any((value) => value.contains(query)))
          const UtilityEmpty(
            icon: CupertinoIcons.link,
            title: 'No matching connections.',
            message: 'Try a different name or file type.',
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
