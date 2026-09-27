import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';

Future<InventoryItem?> showManualAddPage(
  BuildContext context, {
  required ApiClient api,
  String? initialLocation,
  String backLabel = 'Back',
}) => Navigator.of(context).push<InventoryItem>(
  MaterialPageRoute(
    builder: (_) => ManualAddPage(
      api: api,
      initialLocation: initialLocation,
      backLabel: backLabel,
    ),
  ),
);

class ManualAddPage extends StatefulWidget {
  const ManualAddPage({
    super.key,
    required this.api,
    this.initialLocation,
    this.backLabel = 'Back',
  });

  final ApiClient api;
  final String? initialLocation;
  final String backLabel;

  @override
  State<ManualAddPage> createState() => _ManualAddPageState();
}

class _ManualAddPageState extends State<ManualAddPage> {
  static const _kinds = [
    'Consumable',
    'Tool',
    'Equipment',
    'Material',
    'Part',
    'Other',
  ];

  final _name = TextEditingController();
  Timer? _searchTimer;
  int _searchVersion = 0;
  int _quantity = 1;
  String _kind = 'Other';
  String? _location;
  List<String> _spaces = const [];
  List<InventoryItem> _matches = const [];
  InventoryItem? _selectedMatch;
  bool _spacesLoading = true;
  bool _checking = false;
  bool _checked = false;
  bool _createDespiteMatches = false;
  bool _saving = false;
  String? _spaceError;
  String? _searchError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation?.trim();
    _location = initial == null || initial.isEmpty ? null : initial;
    unawaited(_loadSpaces());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    setState(() {
      _spacesLoading = true;
      _spaceError = null;
    });
    try {
      final rows = await widget.api.listSpaces();
      final names =
          rows
              .map((row) => (row['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _spaces = names;
      });
    } catch (error) {
      if (mounted) setState(() => _spaceError = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _spacesLoading = false);
    }
  }

  void _nameChanged(String value) {
    _searchTimer?.cancel();
    final version = ++_searchVersion;
    setState(() {
      _selectedMatch = null;
      _matches = const [];
      _checked = false;
      _checking = false;
      _createDespiteMatches = false;
      _searchError = null;
      _saveError = null;
    });
    if (value.trim().length < 2) return;
    _searchTimer = Timer(
      const Duration(milliseconds: 400),
      () => _search(value.trim(), version),
    );
  }

  Future<void> _search(String query, int version) async {
    if (!mounted || version != _searchVersion) return;
    setState(() => _checking = true);
    try {
      final result = await widget.api.searchItems(query: query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _matches = result.items.take(5).toList();
        _checked = true;
      });
    } catch (error) {
      if (!mounted || version != _searchVersion) return;
      setState(() => _searchError = describeError(error).$1);
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _chooseLocation() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_spaces.isEmpty) const ListTile(title: Text('No places yet')),
              for (final space in _spaces)
                ListTile(
                  title: Text(space),
                  onTap: () => Navigator.pop(context, space),
                ),
              ListTile(
                title: const Text('Create a place'),
                onTap: () => Navigator.pop(context, '__create__'),
              ),
              if (_spaceError != null)
                ListTile(
                  title: const Text('Try loading places again'),
                  onTap: () => Navigator.pop(context, '__retry__'),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == '__retry__') {
      await _loadSpaces();
    } else if (selected == '__create__') {
      await _createSpace();
    } else if (selected != null && mounted) {
      setState(() {
        _location = selected;
        _selectedMatch = null;
      });
    }
  }

  Future<void> _createSpace() async {
    final name = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New place'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Place name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    if (selected == null || selected.isEmpty) return;
    try {
      await widget.api.createSpace(name: selected);
      await _loadSpaces();
      if (mounted && _spaces.contains(selected)) {
        setState(() => _location = selected);
      }
    } catch (error) {
      if (mounted) setState(() => _spaceError = describeError(error).$1);
    }
  }

  Future<void> _save() async {
    if (_saving || !_checked || _checking || _searchError != null) return;
    final name = _name.text.trim();
    final location = _location;
    if (name.length < 2 ||
        (_selectedMatch == null && (location == null || location.isEmpty))) {
      return;
    }
    if (_matches.isNotEmpty &&
        _selectedMatch == null &&
        !_createDespiteMatches) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    var saved = false;
    try {
      final selected = _selectedMatch;
      final current = selected == null
          ? null
          : await widget.api.itemDetail(selected.itemId);
      final item = selected == null
          ? await widget.api.addItem(
              item: AddItemRequest(
                name: name,
                location: location!,
                category: _kind,
                quantity: _quantity,
              ),
            )
          : await widget.api.updateItem(
              request: UpdateItemRequest(
                itemId: selected.itemId,
                quantity: current!.quantity + _quantity,
              ),
            );
      saved = true;
      if (mounted) Navigator.pop(context, item);
    } catch (error) {
      if (mounted) setState(() => _saveError = describeError(error).$1);
    } finally {
      if (mounted && !saved) setState(() => _saving = false);
    }
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
    final selected = _selectedMatch;
    final canSave =
        !_saving &&
        _checked &&
        !_checking &&
        _searchError == null &&
        _name.text.trim().length >= 2 &&
        (selected != null || _location?.isNotEmpty == true) &&
        (_matches.isEmpty || selected != null || _createDespiteMatches);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.backLabel),
                  ),
                  Expanded(
                    child: Text(
                      'Add',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: canSave ? _save : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                    ),
                    child: Column(
                      children: [
                        _row(
                          t,
                          'What',
                          TextField(
                            controller: _name,
                            onChanged: _nameChanged,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Name the object',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: t.separator),
                        _row(
                          t,
                          'Where',
                          TextButton(
                            onPressed: _chooseLocation,
                            child: Text(
                              _location ??
                                  (_spacesLoading
                                      ? 'Loading places'
                                      : 'Choose a place'),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: t.separator),
                        _row(
                          t,
                          'How many',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                child: const Text('−'),
                              ),
                              Text(
                                '$_quantity',
                                style: TextStyle(
                                  color: t.ink,
                                  fontFamily: 'IBMPlexMono',
                                  fontSize: 17,
                                ),
                              ),
                              TextButton(
                                onPressed: _quantity < 99999
                                    ? () => setState(() => _quantity++)
                                    : null,
                                child: const Text('+'),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: t.separator),
                        _row(
                          t,
                          'Kind',
                          DropdownButton<String>(
                            value: _kind,
                            icon: const SizedBox.shrink(),
                            underline: const SizedBox.shrink(),
                            items: _kinds
                                .map(
                                  (kind) => DropdownMenuItem(
                                    value: kind,
                                    child: Text(kind),
                                  ),
                                )
                                .toList(),
                            onChanged: (kind) {
                              if (kind != null) setState(() => _kind = kind);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_spaceError != null) ...[
                    const SizedBox(height: 10),
                    Text(_spaceError!, style: TextStyle(color: t.danger)),
                    TextButton(
                      onPressed: _loadSpaces,
                      child: const Text('Try places again'),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'It thinks you mean',
                    style: TextStyle(
                      color: t.text3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_name.text.trim().length < 2)
                    Text(
                      'Type a name to check what you already own.',
                      style: TextStyle(color: t.text2, fontSize: 15),
                    )
                  else if (_checking || !_checked && _searchError == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_searchError != null) ...[
                    Text(
                      'Could not check existing objects.',
                      style: TextStyle(color: t.danger, fontSize: 15),
                    ),
                    TextButton(
                      onPressed: () =>
                          _search(_name.text.trim(), ++_searchVersion),
                      child: const Text('Try again'),
                    ),
                  ] else if (_matches.isEmpty)
                    Text(
                      'No matching objects found.',
                      style: TextStyle(color: t.text2, fontSize: 15),
                    )
                  else ...[
                    for (final match in _matches) _matchRow(t, match),
                    if (selected == null)
                      TextButton(
                        onPressed: () =>
                            setState(() => _createDespiteMatches = true),
                        child: Text(
                          _createDespiteMatches
                              ? 'Create a separate object selected'
                              : 'None of these, create a separate object',
                        ),
                      ),
                  ],
                  const SizedBox(height: 22),
                  if (selected != null)
                    Text(
                      'Adding to ${selected.name} in ${_path(selected)}. The count will become ${selected.quantity + _quantity}.',
                      style: TextStyle(color: t.text2, fontSize: 14),
                    ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _saveError!,
                      style: TextStyle(color: t.danger, fontSize: 15),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSave ? _save : null,
                      child: Text(
                        _saving
                            ? 'Saving'
                            : selected != null
                            ? 'Add to existing object'
                            : 'Save new object',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A photo can come later. This object can hold history, project links and documents.',
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

  Widget _row(AppTokens t, String label, Widget field) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: TextStyle(color: t.text2, fontSize: 14)),
        ),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: field),
        ),
      ],
    ),
  );

  Widget _matchRow(AppTokens t, InventoryItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: _selectedMatch?.itemId == item.itemId ? t.s3 : t.card,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            _selectedMatch = item;
            _createDespiteMatches = false;
            _location = item.location;
            _kind = _kinds.contains(item.category) ? item.category : 'Other';
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(color: t.ink, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.quantity} in ${_path(item)}',
                      style: TextStyle(color: t.text2, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                'match',
                style: TextStyle(
                  color: t.accentText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
