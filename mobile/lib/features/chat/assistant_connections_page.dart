import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/external_links.dart';

/// Existing outbound assistant setup. No inferred connection or OAuth status.
class AssistantConnectionsPage extends StatefulWidget {
  const AssistantConnectionsPage({super.key});
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
        const Text('AI assistants', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        const Text(
          'Use your FindEZ inventory from an assistant. Manage setup and scoped API keys on the web.',
        ),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.$2} - Setup on web',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(entry.$3),
                    TextButton.icon(
                      onPressed: () => _open('/docs/api#ai-assistants'),
                      icon: const Icon(CupertinoIcons.arrow_up_right, size: 16),
                      label: const Text('View setup'),
                    ),
                  ],
                ),
              ),
            ),
        if (query.isNotEmpty &&
            ![
              'claude desktop mcp extension',
              'chatgpt actions',
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
        const SizedBox(height: 16),
        const Text(
          'To bring data into FindEZ now, use Attach for PDF or text, or Import inventory for CSV and Excel. These assistant connections do not import email or cloud files.',
        ),
      ],
    ),
  );
}
