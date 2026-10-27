import '../../core/account_refresh.dart';
import '../../core/ui/native_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/memory_controller.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/utility_page.dart';
import 'package:flutter/cupertino.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final MemoryController store;
  late final AccountRefresh _accountRefresh;
  final alias = TextEditingController();
  String? spaceId;
  @override
  void initState() {
    super.initState();
    store = MemoryController(widget.api)..addListener(_changed);
    unawaited(store.load());
    _accountRefresh = AccountRefresh(
      refresh: () => store.load(quiet: true),
      isActive: () =>
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          !store.busy &&
          store.pending == null &&
          alias.text.isEmpty,
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _accountRefresh.dispose();
    store.removeListener(_changed);
    store.dispose();
    alias.dispose();
    super.dispose();
  }

  Future<void> _forget() async {
    final yes = await showAppConfirmation(
      context,
      title: 'Forget personalization?',
      message:
          'This removes your preferences, aliases and unverified legacy memory. Your chats and inventory stay saved.',
      confirmLabel: 'Forget',
    );
    if (yes == true) await store.change({'action': 'clear'});
  }

  Widget _choice(String key, String title, List<String> values) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(
            '$key:${store.preference(key)}:${store.snapshot?['revision']}',
          ),
          initialValue: store.preference(key) ?? '',
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: const InputDecoration(),
          items: [
            DropdownMenuItem(
              value: '',
              child: AppText(
                'Default',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ...values.map(
              (v) => DropdownMenuItem(
                value: v,
                child: AppText(
                  '${v[0].toUpperCase()}${v.substring(1)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          onChanged: store.busy || store.pending != null || !store.enabled
              ? null
              : (value) => unawaited(
                  store.change(
                    value == ''
                        ? {'action': 'delete', 'key': key}
                        : {'action': 'set', 'key': key, 'value': value},
                  ),
                ),
        ),
      ],
    ),
  );

  Future<void> _export() async {
    final result = await store.export();
    if (result == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Memory export'),
        content: SingleChildScrollView(child: SelectableText(result)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const AppText('Copy JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = store.busy || store.pending != null;
    final text = Theme.of(context).textTheme;
    return UtilityPage(
      title: 'Memory',
      actions: [
        IconButton(
          tooltip: 'Refresh memory',
          onPressed: store.busy ? null : store.load,
          icon: const Icon(CupertinoIcons.refresh, size: 20),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: store.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const UtilityHint(
              'Your chosen preferences are private and sync across your devices.',
            ),
            if (store.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (store.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AppText(
                  store.error!,
                  semanticsLabel: 'Memory error: ${store.error}',
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (store.notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: UtilityHint(store.notice!),
              ),
            if (store.pending != null)
              TextButton(
                onPressed: store.busy ? null : () => store.change(null),
                child: const AppText('Retry save'),
              ),
            if (store.snapshot != null) ...[
              const UtilitySection('Personalization'),
              UtilityCard(
                child: SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: AppText('Use personalization', style: text.titleSmall),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: UtilityHint(
                      'Use your preferences in replies. Turning this off keeps them saved.',
                    ),
                  ),
                  value: store.enabled,
                  onChanged: blocked
                      ? null
                      : (v) =>
                            store.change({'action': 'settings', 'enabled': v}),
                ),
              ),
              const UtilitySection(
                'Response style',
                description: 'Choose how FindEZ answers you.',
              ),
              UtilityCard(
                child: Column(
                  children: [
                    _choice('answer_length', 'Answer length', [
                      'brief',
                      'standard',
                      'detailed',
                    ]),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _choice('answer_format', 'Answer format', [
                      'paragraphs',
                      'bullets',
                    ]),
                  ],
                ),
              ),
              if (store.entries.any((e) => e['kind'] == 'preference'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: UtilityCard(
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: AppText(
                        'Saved preferences',
                        style: text.titleSmall,
                      ),
                      children: [
                        for (final entry in store.entries.where(
                          (e) => e['kind'] == 'preference',
                        ))
                          ListTile(
                            title: AppText(
                              entry['key'].toString().replaceAll('_', ' '),
                              style: text.bodyMedium,
                            ),
                            subtitle: UtilityHint(
                              '${(entry['payload'] as Map)['value']} - ${entry['source']}\nSaved ${entry['confirmed_at']}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (store.inventoryId != null) ...[
                const UtilitySection(
                  'Location aliases',
                  description:
                      'Private names for saved locations. Aliases do not move items.',
                ),
                UtilityCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('Alias', style: text.bodySmall),
                        const SizedBox(height: 8),
                        TextField(
                          controller: alias,
                          enabled: !blocked && store.enabled,
                          maxLength: 60,
                          style: text.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Tool cupboard',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        AppText('Saved location', style: text.bodySmall),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: spaceId,
                          isExpanded: true,
                          style: text.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Choose a location',
                          ),
                          items: store.spaces
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s['id'].toString(),
                                  child: AppText(
                                    s['name'].toString(),
                                    style: text.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: blocked || !store.enabled
                              ? null
                              : (v) => setState(() => spaceId = v),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed:
                              blocked ||
                                  !store.enabled ||
                                  alias.text.trim().isEmpty ||
                                  spaceId == null
                              ? null
                              : () => store.change({
                                  'action': 'set',
                                  'inventory_id': store.inventoryId,
                                  'alias': alias.text.trim(),
                                  'space_id': spaceId,
                                }),
                          child: const AppText('Save alias'),
                        ),
                        for (final entry in store.entries.where(
                          (e) => e['kind'] == 'alias',
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: AppText(
                              (entry['payload'] as Map)['alias'].toString(),
                              style: text.bodyMedium,
                            ),
                            subtitle: UtilityHint(
                              _location(
                                (entry['payload'] as Map)['space_id']
                                    .toString(),
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Forget alias',
                              icon: const Icon(CupertinoIcons.trash, size: 18),
                              onPressed: blocked
                                  ? null
                                  : () => store.change({
                                      'action': 'delete',
                                      'inventory_id': store.inventoryId,
                                      'alias':
                                          (entry['payload'] as Map)['alias'],
                                    }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if ((store.snapshot!['legacy'] as List? ?? []).isNotEmpty) ...[
                const SizedBox(height: 16),
                UtilityCard(
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: AppText(
                      'Unverified legacy memory',
                      style: text.titleSmall,
                    ),
                    subtitle: const UtilityHint(
                      'Excluded from personalization',
                    ),
                    children: [
                      for (final entry in store.snapshot!['legacy'] as List)
                        ListTile(
                          title: AppText(
                            '${entry['key']}',
                            style: text.bodyMedium,
                          ),
                          subtitle: UtilityHint('${entry['value']}'),
                        ),
                    ],
                  ),
                ),
              ],
              const UtilitySection('Manage memory'),
              UtilityCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        CupertinoIcons.square_arrow_up,
                        size: 20,
                      ),
                      title: AppText('Export memory', style: text.bodyMedium),
                      subtitle: const UtilityHint(
                        'View and copy your saved preferences',
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                      ),
                      onTap: blocked ? null : _export,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(
                        CupertinoIcons.trash,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: AppText(
                        'Forget personalization',
                        style: text.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const UtilityHint(
                        'Your chats and inventory stay saved',
                      ),
                      onTap: blocked ? null : _forget,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _location(String id) {
    for (final space in store.spaces) {
      if (space['id'] == id) return space['name'].toString();
    }
    return 'Unavailable location';
  }
}
