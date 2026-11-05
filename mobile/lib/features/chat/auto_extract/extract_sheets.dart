import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'extract_style.dart';
import 'extract_widgets.dart';

class ExtractEditSheet extends StatefulWidget {
  const ExtractEditSheet({super.key, required this.row, required this.missing});
  final Map<String, dynamic> row;
  final bool missing;
  @override
  State<ExtractEditSheet> createState() => _ExtractEditSheetState();
}

class _ExtractEditSheetState extends State<ExtractEditSheet> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final key in [
      'name',
      'quantity',
      'category',
      'brand',
      'part_number',
      'notes',
    ])
      key: TextEditingController(
        text: key == 'quantity' && widget.missing
            ? ''
            : '${widget.row['item'][key] ?? ''}',
      ),
  };
  bool _more = false;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: ExtractStyle.of(context).s2,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: ExtractStyle.of(
            context,
          ).text(11.5, color: ExtractStyle.of(context).tx2),
        ),
        TextFormField(
          controller: _fields[key],
          style: ExtractStyle.of(context).text(16.5),
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.only(top: 2),
          ),
          validator: (v) =>
              ['name', 'category'].contains(key) && (v ?? '').trim().isEmpty
              ? 'Required'
              : null,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.row['item']['image_url'] is String)
          ExtractPhoto(
            url: widget.row['item']['image_url'],
            height: 150,
            width: double.infinity,
            radius: 20,
          ),
        const SizedBox(height: 10),
        field('name', 'Name'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, bounds) {
            final fields = [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ExtractStyle.of(context).s2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Quantity',
                      style: ExtractStyle.of(
                        context,
                      ).text(11.5, color: ExtractStyle.of(context).tx2),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Decrease quantity',
                          onPressed: () {
                            final n =
                                int.tryParse(_fields['quantity']!.text) ?? 1;
                            setState(
                              () => _fields['quantity']!.text =
                                  '${n > 1 ? n - 1 : 1}',
                            );
                          },
                          icon: Icon(
                            CupertinoIcons.minus,
                            size: 16,
                            color: ExtractStyle.of(context).tx,
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _fields['quantity'],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: ExtractStyle.of(context).text(20),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 || n > 100000
                                  ? 'Enter a count'
                                  : null;
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase quantity',
                          onPressed: () {
                            final n =
                                int.tryParse(_fields['quantity']!.text) ?? 0;
                            setState(
                              () => _fields['quantity']!.text =
                                  '${n < 100000 ? n + 1 : 100000}',
                            );
                          },
                          icon: Icon(
                            CupertinoIcons.plus,
                            size: 16,
                            color: ExtractStyle.of(context).tx,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              field('notes', 'Details'),
            ];
            return bounds.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(16) > 24
                ? Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 10),
                      fields[1],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[1]),
                    ],
                  );
          },
        ),
        TextButton(
          onPressed: () => setState(() => _more = !_more),
          child: AppText(
            _more ? 'Fewer details' : 'More details',
            style: ExtractStyle.of(
              context,
            ).text(12.5, color: ExtractStyle.of(context).tx2),
          ),
        ),
        if (_more) ...[
          field('category', 'Category'),
          const SizedBox(height: 10),
          field('brand', 'Brand'),
          const SizedBox(height: 10),
          field('part_number', 'Part number'),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 10,
              child: FilledButton(
                style: ExtractStyle.of(context)
                    .pill(height: 52)
                    .copyWith(
                      foregroundColor: WidgetStatePropertyAll(
                        ExtractStyle.of(context).red,
                      ),
                    ),
                onPressed: () => Navigator.pop(context, {
                  'index': widget.row['index'],
                  'selected': false,
                }),
                child: const AppText('Leave out'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 14,
              child: FilledButton(
                style: ExtractStyle.of(context).pill(primary: true, height: 52),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(context, {
                    'index': widget.row['index'],
                    'selected': true,
                    for (final e in _fields.entries)
                      e.key: e.key == 'quantity'
                          ? int.parse(e.value.text)
                          : e.value.text.trim(),
                  });
                },
                child: const AppText('Done'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ExtractSpaceSheet extends StatefulWidget {
  const ExtractSpaceSheet({
    super.key,
    required this.groups,
    required this.selected,
    required this.count,
    required this.onCreate,
  });
  final List<Map> groups;
  final String? selected;
  final int count;
  final Future<Map<String, dynamic>> Function(Map group, String name) onCreate;
  @override
  State<ExtractSpaceSheet> createState() => _ExtractSpaceSheetState();
}

class _ExtractSpaceSheetState extends State<ExtractSpaceSheet> {
  final _search = TextEditingController();
  Map? _newGroup;
  bool _creating = false;
  String? _error;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget tile(String name, {bool plus = false}) {
    const palettes = [
      [Color(0xffb9bec5), Color(0xff6e747d), Color(0xff24272c)],
      [Color(0xff3e5a4c), Color(0xff6f8c74), Color(0xff22322c)],
      [Color(0xff9aa6b2), Color(0xff4e5878), Color(0xff151729)],
      [Color(0xff2b2440), Color(0xff6b5486), Color(0xffa7808f)],
    ];
    final hash = name.codeUnits.fold<int>(0, (v, c) => (v * 31 + c) & 0xffff);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ExtractStyle.of(context).s3,
        borderRadius: BorderRadius.circular(12),
        gradient: plus
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palettes[hash % 4],
              ),
      ),
      child: plus
          ? Icon(
              CupertinoIcons.plus,
              size: 18,
              color: ExtractStyle.of(context).tx,
            )
          : null,
    );
  }

  Future<void> create() async {
    if (_creating || _search.text.trim().isEmpty || _newGroup == null) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final selected = await widget.onCreate(_newGroup!, _search.text.trim());
      if (mounted) Navigator.pop(context, selected);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Could not create this Space. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          'Save ${widget.count} ${widget.count == 1 ? 'item' : 'items'} to…',
          style: ExtractStyle.of(context).text(22),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          enabled: !_creating,
          style: ExtractStyle.of(context).text(15.5),
          decoration: InputDecoration(
            hintText: 'Search Spaces',
            hintStyle: ExtractStyle.of(
              context,
            ).text(15.5, color: ExtractStyle.of(context).tx2),
            prefixIcon: Icon(
              CupertinoIcons.search,
              size: 17,
              color: ExtractStyle.of(context).tx2,
            ),
            filled: true,
            fillColor: ExtractStyle.of(context).s2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(23),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(23),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final group in widget.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
            child: AppText(
              '${group['workspace_name']} · ${group['name']}',
              style: ExtractStyle.of(
                context,
              ).text(12.5, color: ExtractStyle.of(context).tx3),
            ),
          ),
          for (final space
              in (group['spaces'] as List? ?? []).whereType<Map>().where(
                (s) => '${s['name']}'.toLowerCase().contains(query),
              ))
            Material(
              color: space['id'] == widget.selected
                  ? ExtractStyle.of(context).s2
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                leading: tile('${space['name']}'),
                title: AppText(
                  '${space['name']}',
                  style: ExtractStyle.of(context).text(15.5),
                ),
                subtitle: AppText(
                  space['item_count'] == 0
                      ? 'Empty'
                      : '${group['name']}${space['item_count'] is num ? ' · ${space['item_count']} items' : ''}',
                  style: ExtractStyle.of(
                    context,
                  ).text(12.5, color: ExtractStyle.of(context).tx2),
                ),
                trailing: space['id'] == widget.selected
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: ExtractStyle.of(context).white,
                        child: Icon(
                          CupertinoIcons.check_mark,
                          size: 13,
                          color: ExtractStyle.of(context).ink,
                        ),
                      )
                    : null,
                onTap: _creating
                    ? null
                    : () => Navigator.pop(context, {
                        'inventory_id': group['inventory_id'],
                        'space_id': space['id'],
                      }),
              ),
            ),
        ],
        if (widget.groups.isEmpty)
          AppText(
            'No writable inventories. Ask chat to create one, or request edit access.',
            style: ExtractStyle.of(
              context,
            ).text(14, color: ExtractStyle.of(context).tx2),
          ),
        if (widget.groups.isNotEmpty)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            leading: tile('', plus: true),
            title: AppText(
              query.isEmpty
                  ? 'New Space'
                  : 'New Space “${_search.text.trim()}”',
              style: ExtractStyle.of(context).text(15.5),
            ),
            subtitle: AppText(
              'Create it and save here',
              style: ExtractStyle.of(
                context,
              ).text(12.5, color: ExtractStyle.of(context).tx2),
            ),
            onTap: _creating
                ? null
                : () => setState(() => _newGroup = widget.groups.first),
          ),
        if (_newGroup != null) ...[
          if (query.isEmpty)
            AppText(
              'Enter a name in Search Spaces above.',
              style: ExtractStyle.of(
                context,
              ).text(14, color: ExtractStyle.of(context).tx2),
            ),
          DropdownButtonFormField<String>(
            initialValue: '${_newGroup!['inventory_id']}',
            dropdownColor: ExtractStyle.of(context).s2,
            style: ExtractStyle.of(context).text(14),
            items: [
              for (final group in widget.groups)
                DropdownMenuItem(
                  value: '${group['inventory_id']}',
                  child: AppText(
                    '${group['workspace_name']} · ${group['name']}',
                  ),
                ),
            ],
            onChanged: _creating
                ? null
                : (id) => setState(
                    () => _newGroup = widget.groups.firstWhere(
                      (g) => g['inventory_id'] == id,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: ExtractStyle.of(context).pill(primary: true),
            onPressed: _creating || query.isEmpty ? null : create,
            child: AppText(_creating ? 'Creating…' : 'Create Space'),
          ),
        ],
        if (_error != null)
          AppText(
            _error!,
            style: ExtractStyle.of(
              context,
            ).text(14, color: ExtractStyle.of(context).red),
          ),
      ],
    );
  }
}
