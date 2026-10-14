import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ask_answer.dart';
import '../../core/ui/app_text.dart';
import '../chat/ask_answer_view.dart';

String _label(Map<String, dynamic> row) =>
    row['native_label']?.toString() ??
    '${row['product_title'] ?? 'Product'} / ${row['variant_title'] ?? 'Variant'}';
List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : [];
String _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal().toString() ??
    'Time unavailable';
String _destination(Map<String, dynamic> row) => [
  row['space_name'],
  row['bin_name'],
].where((value) => value != null).join(' / ');
String _requestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

class TeamPhysicalMemoryPage extends StatefulWidget {
  const TeamPhysicalMemoryPage({
    super.key,
    required this.api,
    required this.teamId,
  });
  final ApiClient api;
  final String teamId;
  @override
  State<TeamPhysicalMemoryPage> createState() => _TeamPhysicalMemoryPageState();
}

class _TeamPhysicalMemoryPageState extends State<TeamPhysicalMemoryPage> {
  final _question = TextEditingController();
  Map<String, dynamic>? _options, _answer, _selected;
  String? _owner, _error;
  bool _barcode = false, _busy = false, _editing = false;
  int _epoch = 0, _scopeEpoch = 0;
  StreamSubscription<AuthState>? _auth;
  Timer? _accessRefresh;
  bool get _current =>
      mounted && _owner != null && widget.api.accountId == _owner;
  @override
  void initState() {
    super.initState();
    _owner = widget.api.accountId;
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted && widget.api.accountId != _owner) _invalidate();
    });
    unawaited(_loadOptions());
    _accessRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_current && !_busy && !_editing) unawaited(_loadOptions());
    });
  }

  void _invalidate() {
    _epoch++;
    _scopeEpoch++;
    _question.clear();
    setState(() {
      _answer = null;
      _selected = null;
      _options = null;
      _busy = false;
      _editing = false;
      _error = 'Your account changed. Reopen this Team.';
    });
  }

  @override
  void didUpdateWidget(covariant TeamPhysicalMemoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.api != widget.api) {
      _invalidate();
      _owner = widget.api.accountId;
      unawaited(_loadOptions());
    }
  }

  Future<void> _loadOptions() async {
    final epoch = ++_scopeEpoch;
    try {
      final result = await widget.api.getPhysicalOptions(widget.teamId);
      if (!_current || epoch != _scopeEpoch) return;
      setState(() {
        _options = result;
        _error = null;
      });
    } catch (error) {
      if (_current && epoch == _scopeEpoch) {
        setState(() {
          if (error is DioException &&
              [401, 403].contains(error.response?.statusCode)) {
            _epoch++;
            _options = null;
            _answer = null;
            _selected = null;
            _question.clear();
          }
          _error = describeError(error).$1;
        });
      }
    }
  }

  Future<void> _lookup({Map<String, dynamic>? candidate}) async {
    if (!_current ||
        _busy ||
        _editing ||
        (_question.text.trim().isEmpty && candidate == null)) {
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
      _selected = null;
    });
    try {
      final query = candidate == null
          ? {
              'question': _question.text.trim(),
              if (_barcode) 'barcode': _question.text.trim(),
            }
          : {
              'question': 'Where is this product?',
              if (candidate['memory_id'] != null)
                'memory_id': candidate['memory_id']
              else ...{
                'connection_id': candidate['connection_id'],
                'variant_gid': candidate['variant_gid'],
              },
            };
      final result = await widget.api.askPhysical(widget.teamId, query);
      if (!_current || epoch != _epoch) return;
      final candidates = _rows((result['result'] as Map?)?['candidates']);
      setState(() {
        _answer = result;
        _selected = candidates.length == 1 ? candidates.first : null;
      });
    } catch (error) {
      if (_current && epoch == _epoch) {
        setState(() {
          _error = describeError(error).$1;
        });
      }
    } finally {
      if (_current && epoch == _epoch) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    _auth?.cancel();
    _accessRefresh?.cancel();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _rows((_answer?['result'] as Map?)?['candidates']);
    return Scaffold(
      appBar: AppBar(title: const AppText('Physical memory')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const AppText('Find a product. Confirm where it belongs.'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('physical-question'),
              controller: _question,
              enabled: !_busy && !_editing && _current,
              maxLength: _barcode ? 255 : 4000,
              decoration: InputDecoration(
                labelText: _barcode ? 'Exact barcode' : 'Ask this Team',
                hintText: _barcode
                    ? 'Keep leading zeros'
                    : 'Where is the black medium hoodie?',
              ),
              onSubmitted: (_) => _lookup(),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText('Search by barcode'),
              value: _barcode,
              onChanged: _busy || _editing
                  ? null
                  : (value) => setState(() {
                      _barcode = value ?? false;
                    }),
            ),
            FilledButton(
              key: const Key('physical-find'),
              onPressed: _busy || _editing || !_current
                  ? null
                  : () => _lookup(),
              child: AppText(_busy ? 'Checking...' : 'Find'),
            ),
            if (_options == null && _current)
              TextButton(
                onPressed: _loadOptions,
                child: const AppText('Retry locations'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AppText(_error!, semanticsLabel: 'Error: $_error'),
              ),
            if (_answer != null) ...[
              const SizedBox(height: 18),
              AskAnswerView(
                answer: _answer!['assistant_message']?.toString() ?? '',
                contextData: AskAnswerContext.fromJson(
                  Map<String, dynamic>.from(_answer!['answer_context'] ?? {}),
                ),
              ),
            ],
            if (candidates.length > 1) ...[
              for (final candidate in candidates)
                Card(
                  child: ListTile(
                    title: AppText(_label(candidate)),
                    subtitle: AppText(
                      'SKU: ${candidate['sku'] ?? 'Not supplied'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : () => _lookup(candidate: candidate),
                  ),
                ),
              if ((_answer?['result'] as Map?)?['truncated'] == true)
                const AppText(
                  'More matches exist. Narrow the name, size, or color.',
                ),
            ],
            if (_selected != null && _options != null)
              PhysicalLocationForm(
                key: ValueKey(
                  '${widget.teamId}:$_owner:${_selected!['memory_id'] ?? _selected!['variant_gid']}',
                ),
                api: widget.api,
                teamId: widget.teamId,
                candidate: _selected!,
                options: _options!,
                barcode: _barcode ? _question.text.trim() : null,
                isCurrent: () => _current,
                onBusy: (value) {
                  if (_current) {
                    setState(() {
                      _editing = value;
                    });
                  }
                },
                onSaved: (memory) async {
                  if (_current) {
                    setState(() {
                      _editing = false;
                    });
                    await _lookup(candidate: {'memory_id': memory});
                  }
                },
                onAccessDenied: () {
                  if (_current) {
                    setState(() {
                      _epoch++;
                      _scopeEpoch++;
                      _question.clear();
                      _editing = false;
                      _busy = false;
                      _selected = null;
                      _answer = null;
                      _options = null;
                      _error = 'Team access is no longer available.';
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class PhysicalLocationForm extends StatefulWidget {
  const PhysicalLocationForm({
    super.key,
    required this.api,
    required this.teamId,
    required this.candidate,
    required this.options,
    required this.isCurrent,
    required this.onSaved,
    required this.onBusy,
    required this.onAccessDenied,
    this.barcode,
  });
  final ApiClient api;
  final String teamId;
  final Map<String, dynamic> candidate, options;
  final bool Function() isCurrent;
  final Future<void> Function(String) onSaved;
  final void Function(bool) onBusy;
  final VoidCallback onAccessDenied;
  final String? barcode;
  @override
  State<PhysicalLocationForm> createState() => _PhysicalLocationFormState();
}

class _PhysicalLocationFormState extends State<PhysicalLocationForm> {
  late final TextEditingController _name;
  final _count = TextEditingController();
  String? _space, _bin, _placement, _error, _request, _serialized;
  bool _saving = false;
  List<Map<String, dynamic>>? _history;
  List<Map<String, dynamic>> get _spaces => _rows(widget.options['spaces']);
  List<Map<String, dynamic>> get _placements =>
      _rows(widget.candidate['placements']);
  Map<String, dynamic>? get _record =>
      _placements.where((r) => r['placement_id'] == _placement).firstOrNull;
  bool get _current => mounted && widget.isCurrent();
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.candidate['native_label']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<String?> _pick(
    String title,
    List<Map<String, dynamic>> values, {
    bool optional = false,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppText(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (optional)
            ListTile(
              title: const AppText('Space only'),
              onTap: () => Navigator.pop(context, ''),
            ),
          for (final value in values)
            ListTile(
              title: AppText(value['name']?.toString() ?? ''),
              onTap: () => Navigator.pop(context, value['id']?.toString()),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save({bool remove = false}) async {
    if (_saving || !_current) return;
    final count = _count.text.trim().isEmpty
        ? null
        : int.tryParse(_count.text.trim());
    if (!remove &&
        (_name.text.trim().isEmpty ||
            _space == null ||
            (_count.text.trim().isNotEmpty &&
                (count == null || count < 0 || count > 2147483647)))) {
      setState(() {
        _error =
            'Enter a name, choose a Space, and use a whole nonnegative count or leave it blank.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.onBusy(true);
    try {
      if (remove) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('Remove this location?'),
            content: const AppText(
              'Confirmation history stays in FindEZ. Inventory stock does not change.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('Remove location'),
              ),
            ],
          ),
        );
        if (approved != true) return;
      }
      if (!_current) return;
      final body = <String, dynamic>{
        'native_label': _name.text.trim(),
        if (widget.candidate['memory_id'] != null)
          'memory_id': widget.candidate['memory_id']
        else ...{
          'connection_id': widget.candidate['connection_id'],
          'variant_gid': widget.candidate['variant_gid'],
          if (widget.barcode != null) 'barcode': widget.barcode,
        },
        'placement_id': _placement,
        'expected_revision': _record?['revision'] ?? 0,
        'space_id': _space,
        'bin_id': _bin,
        'observed_count': count,
        'action': remove ? 'remove' : 'confirm',
      };
      final serialized = jsonEncode(body);
      if (serialized != _serialized) {
        _serialized = serialized;
        _request = _requestId();
      }
      final receipt = await widget.api.confirmPhysical(widget.teamId, {
        ...body,
        'request_id': _request,
      });
      if (receipt['observation_id'] is! String ||
          receipt['memory_id'] is! String) {
        throw const FormatException('The confirmation was not saved');
      }
      if (_current) {
        widget.onBusy(false);
        await widget.onSaved(receipt['memory_id'] as String);
      }
    } catch (error) {
      if (_current) {
        if (error is DioException &&
            [401, 403].contains(error.response?.statusCode)) {
          widget.onAccessDenied();
        } else {
          setState(() {
            _error = describeError(error).$1;
          });
        }
      }
    } finally {
      if (_current) {
        setState(() {
          _saving = false;
        });
        widget.onBusy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = widget.options['can_confirm'] == true;
    final bins = _rows(
      _spaces.where((r) => r['id'] == _space).firstOrNull?['bins'],
    );
    final spaceName = _spaces
        .where((r) => r['id'] == _space)
        .firstOrNull?['name']
        ?.toString();
    final binName = bins
        .where((r) => r['id'] == _bin)
        .firstOrNull?['name']
        ?.toString();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            canConfirm ? 'Confirm a physical location' : 'Confirmed locations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!canConfirm)
            const AppText(
              'You have view-only access. An editor can confirm a location.',
            ),
          if (canConfirm) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('physical-native-name'),
              controller: _name,
              enabled: !_saving && widget.candidate['native_label'] == null,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'FindEZ name',
                hintText: 'Write the name FindEZ should remember',
              ),
            ),
            const AppText(
              'This name and your confirmation remain in FindEZ after disconnecting Shopify.',
            ),
            if (_placements.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final value = await _pick('Choose a confirmation', [
                          {'id': '', 'name': 'Add another location'},
                          ..._placements.map(
                            (r) => {
                              'id': r['placement_id'],
                              'name': _destination(r),
                            },
                          ),
                        ]);
                        if (_current && value != null) {
                          final record = _placements
                              .where((r) => r['placement_id'] == value)
                              .firstOrNull;
                          setState(() {
                            _placement = value.isEmpty ? null : value;
                            _space = record?['space_id'];
                            _bin = record?['bin_id'];
                            _count.text =
                                record?['observed_count']?.toString() ?? '';
                            _history = null;
                          });
                        }
                      },
                child: AppText(
                  _placement == null
                      ? 'Add another location'
                      : 'Edit saved confirmation',
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('physical-space'),
              onPressed: _saving
                  ? null
                  : () async {
                      final value = await _pick('Choose a Team Space', _spaces);
                      if (_current && value != null) {
                        setState(() {
                          _space = value;
                          _bin = null;
                        });
                      }
                    },
              child: AppText(spaceName ?? 'Choose a Team Space'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('physical-bin'),
              onPressed: _saving || _space == null
                  ? null
                  : () async {
                      final value = await _pick(
                        'Choose a bin',
                        bins,
                        optional: true,
                      );
                      if (_current && value != null) {
                        setState(() {
                          _bin = value.isEmpty ? null : value;
                        });
                      }
                    },
              child: AppText(binName ?? 'Space only'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('physical-count'),
              controller: _count,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Count observed here (optional)',
                hintText: 'Unknown if blank',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('physical-confirm'),
              onPressed: _saving || _spaces.isEmpty ? null : () => _save(),
              child: AppText(_saving ? 'Saving...' : 'Confirm location'),
            ),
            if (_spaces.isEmpty)
              const AppText('Link or create a Team Space first.'),
            if (_placement != null)
              TextButton(
                onPressed: _saving ? null : () => _save(remove: true),
                child: const AppText('Remove location'),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AppText(_error!),
            ),
          for (final row in _placements)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      '${row['space_name']}${row['bin_name'] == null ? '' : ' / ${row['bin_name']}'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    AppText(
                      '${row['actor_label']} / ${_date(row['confirmed_at'])} / Revision ${row['revision']}',
                    ),
                    AppText(
                      row['observed_count'] == null
                          ? 'No physical count recorded'
                          : 'Observed count: ${row['observed_count']}',
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              try {
                                final value = await widget.api
                                    .getPhysicalHistory(
                                      widget.teamId,
                                      row['placement_id'],
                                    );
                                if (_current) {
                                  setState(() {
                                    _history = _rows(value['observations']);
                                  });
                                }
                              } catch (error) {
                                if (_current) {
                                  if (error is DioException &&
                                      [
                                        401,
                                        403,
                                      ].contains(error.response?.statusCode)) {
                                    widget.onAccessDenied();
                                  } else {
                                    setState(() {
                                      _error = describeError(error).$1;
                                    });
                                  }
                                }
                              }
                            },
                      child: const AppText('History'),
                    ),
                  ],
                ),
              ),
            ),
          if (_history != null) ...[
            AppText(
              'Confirmation history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const AppText(
              'Up to 100 recent confirmations from Spaces still linked to this Team.',
            ),
            for (final event in _history!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AppText(
                  'Revision ${event['revision']} / ${event['event_type']} / ${event['space_label']}${event['bin_label'] == null ? '' : ' / ${event['bin_label']}'}\n${event['actor_label']} / ${_date(event['confirmed_at'])} / ${event['observed_count'] == null ? 'No count' : 'Observed ${event['observed_count']}'}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
