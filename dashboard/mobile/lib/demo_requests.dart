import 'package:flutter/material.dart';
import 'dashboard_api.dart';

class DemoRequests extends StatefulWidget {
  final DashboardApi api;
  const DemoRequests({super.key, required this.api});
  @override
  State<DemoRequests> createState() => _DemoRequestsState();
}

String dateText(dynamic seconds) => seconds == null
    ? ''
    : DateTime.fromMillisecondsSinceEpoch(
        (seconds as int) * 1000,
      ).toLocal().toString().split('.').first;
String label(String key) => key.replaceAll('_', ' ');
String display(dynamic value) =>
    value is List ? value.join('\n') : value?.toString() ?? '';

class _DemoRequestsState extends State<DemoRequests> {
  Json list = {}, detail = {};
  String? id;
  String search = '', status = '', category = '', error = '', editor = '';
  int offset = 0;
  bool upcoming = false, busy = false;
  Map<String, String> fields = {};
  String? draftId;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({Json? body, String? operation}) async {
    final seq = ++generation;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (body != null) {
        await widget.api.demoSales(
          id: id,
          operation: operation ?? 'action',
          body: body,
        );
        if (!mounted || seq != generation) return;
        setState(() => editor = '');
      }
      final result = await widget.api.demoSales(
        id: id,
        query: id != null
            ? null
            : {
                'search': search,
                'category': category,
                'status': status,
                'upcoming': '$upcoming',
                'offset': '$offset',
              },
      );
      if (!mounted || seq != generation) return;
      setState(() {
        if (id == null) {
          list = result;
        } else {
          detail = result;
        }
      });
    } catch (e) {
      if (mounted && seq == generation) setState(() => error = e.toString());
    } finally {
      if (mounted && seq == generation) setState(() => busy = false);
    }
  }

  void open(String? next) {
    setState(() {
      id = next;
      editor = '';
      detail = {};
    });
    load();
  }

  void edit(String name, Map<String, String> values, {String? draft}) {
    setState(() {
      editor = name;
      fields = values;
      draftId = draft;
      error = '';
    });
  }

  Widget button(String text, VoidCallback onTap) =>
      OutlinedButton(onPressed: busy ? null : onTap, child: Text(text));
  Widget section(String name, List<Widget> children) => Card(
    child: ExpansionTile(
      title: Text(name),
      childrenPadding: const EdgeInsets.all(14),
      expandedAlignment: Alignment.centerLeft,
      children: children,
    ),
  );
  int instant(String raw) {
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw.trim())) {
      throw const FormatException(
        'Include Z or a UTC offset with each date and time.',
      );
    }
    return DateTime.parse(raw.trim()).millisecondsSinceEpoch ~/ 1000;
  }

  void submitEdit() {
    try {
      if (editor == 'Offer times') {
        load(
          operation: 'offer',
          body: {
            'starts': fields['Available times']!
                .split('\n')
                .where((s) => s.trim().isNotEmpty)
                .map(instant)
                .toList(),
            'location': fields['Meeting link'],
            'minutes': int.parse(fields['Minutes']!),
            'zone': fields['Time zone'],
          },
        );
      } else if (editor == 'Review follow-up') {
        final when = fields['Send at']!.trim();
        load(
          body: {
            'action': 'approve',
            'id': draftId,
            'subject': fields['Subject'],
            'body': fields['Message'],
            'due': when.isEmpty ? 0 : instant(when),
          },
        );
      } else if (editor == 'Pilot details') {
        load(body: {'action': 'pilot', ...fields});
      } else {
        load(
          body: {
            'action': editor == 'Add note' ? 'note' : 'owner',
            'value': fields.values.first,
          },
        );
      }
    } on FormatException {
      setState(
        () => error =
            'Enter a valid duration and dates with UTC offsets, for example 2027-01-12T15:00:00Z.',
      );
    }
  }

  Widget dropdown(
    String title,
    String selected,
    Iterable<dynamic> options,
    void Function(String) changed,
  ) => DropdownButtonFormField<String>(
    initialValue: selected,
    decoration: InputDecoration(labelText: title),
    items: [
      for (final item in options)
        DropdownMenuItem(
          value: item.toString(),
          child: Text(item.toString().isEmpty ? 'All' : item.toString()),
        ),
    ],
    isExpanded: true,
    onChanged: busy
        ? null
        : (v) {
            if (v != null) changed(v);
          },
  );

  List<Widget> listing() {
    final metrics = list['metrics'] ?? {};
    return [
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search name, organization or email',
          suffixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => search = v,
        onSubmitted: (_) {
          offset = 0;
          load();
        },
      ),
      dropdown('Status', status, ['', ...list['statuses'] ?? []], (v) {
        status = v;
        offset = 0;
        load();
      }),
      dropdown(
        'Organization type',
        category,
        ['', ...(metrics['organizations'] ?? {}).keys],
        (v) {
          category = v;
          offset = 0;
          load();
        },
      ),
      SwitchListTile(
        title: const Text('Upcoming meetings'),
        value: upcoming,
        onChanged: busy
            ? null
            : (v) {
                upcoming = v;
                offset = 0;
                load();
              },
      ),
      button('Search / refresh', () {
        offset = 0;
        load();
      }),
      section('Sales metrics', [
        Text('Total requests: ${metrics['total'] ?? 0}'),
        Text('Pilot discussions: ${metrics['pilot_discussions'] ?? 0}'),
        for (final e in (metrics['rates'] ?? {}).entries)
          Text('${e.key}: ${e.value[0]} / ${e.value[1]}'),
        for (final e in (metrics['organizations'] ?? {}).entries)
          Text('${e.key}: ${e.value}'),
      ]),
      section('Integrations', [
        for (final e in (list['integrations'] ?? {}).entries)
          Text('${e.key}: ${e.value}'),
      ]),
      for (final item in list['items'] ?? [])
        Card(
          child: ListTile(
            title: Text('${item['name']} · ${item['organization']}'),
            subtitle: Text(
              [
                item['status'],
                item['email'],
                if (upcoming) dateText(item['starts']),
              ].join('\n'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => open(item['id']),
          ),
        ),
      if (!busy && list.isNotEmpty && (list['items'] as List).isEmpty)
        const Text('No matching requests.'),
      if (offset > 0)
        button('Previous page', () {
          offset -= 50;
          load();
        }),
      if (list['more'] == true)
        button('Next page', () {
          offset += 50;
          load();
        }),
    ];
  }

  List<Widget> record() {
    final m = detail['meeting'], brief = detail['briefing'];
    return [
      button('All requests', () => open(null)),
      if (detail.isNotEmpty) ...[
        Text(detail['submitted']['name'], style: const TextStyle(fontSize: 24)),
        SelectableText(
          '${detail['email']}\n${detail['status']} · Submitted ${dateText(detail['created'])}',
        ),
        section('Prospect details', [
          for (final e in detail['submitted'].entries)
            SelectableText('${label(e.key)}: ${display(e.value)}'),
          Text('Assigned owner: ${detail['owner']}'),
          button(
            'Assign owner',
            () => edit('Assign owner', {'Owner': detail['owner']}),
          ),
        ]),
        section('Briefing · ${detail['brief_state']}', [
          if (brief != null) ...[
            const Text('Submitted organization'),
            Text(brief['organization_overview']),
            Text('Public research: ${brief['public_research']}'),
            const Text('Suggested workflows and hypotheses for review'),
            for (final k in [
              'use_cases',
              'walkthrough',
              'questions',
              'pilot',
              'outreach_draft',
            ])
              SelectableText('${label(k)}\n${display(brief[k])}'),
          ],
          button('Generate briefing', () => load(body: {'action': 'briefing'})),
          button('Refresh', () => load()),
        ]),
        section('Meeting', [
          if (m != null)
            SelectableText(
              "${m['state']} · ${dateText(m['starts'])}\n${m['minutes']} minutes · ${m['zone']}\n${m['location']}",
            ),
          if (m == null || m['state'] == 'offered' || m['state'] == 'cancelled')
            button(
              'Offer available times',
              () => edit('Offer times', {
                'Available times': '',
                'Time zone': 'UTC',
                'Minutes': '30',
                'Meeting link': '',
              }),
            ),
          if (m != null && ['offered', 'confirmed'].contains(m['state']))
            button('Cancel appointment…', () => edit('Cancel appointment', {})),
        ]),
        section('Status and notes', [
          for (final next in [
            'Demo Completed',
            'Follow-Up Required',
            'Pilot Discussion',
            'Converted',
            'Not Proceeding',
          ])
            button(next, () => edit('Set status', {'Status': next})),
          button('Add note', () => edit('Add note', {'Internal note': ''})),
          button(
            'Record prospect response',
            () => load(body: {'action': 'response'}),
          ),
          for (final row in detail['history'])
            ListTile(
              title: Text(row['action']),
              subtitle: SelectableText(
                '${row['detail']}\n${dateText(row['at'])}',
              ),
            ),
        ]),
        section('Pilot opportunity', [
          for (final e in detail['pilot'].entries)
            Text('${label(e.key)}: ${e.value}'),
          button(
            'Edit pilot details',
            () => edit('Pilot details', {
              for (final k in [
                'scope',
                'use_case',
                'participants',
                'onboarding',
                'next_action',
              ])
                k: detail['pilot'][k] ?? '',
            }),
          ),
        ]),
        section('Follow-ups', [
          for (final scenario in ['General', 'Pilot', 'No response'])
            button(
              'Draft · $scenario',
              () => load(body: {'action': 'draft', 'scenario': scenario}),
            ),
          for (final item in detail['followups']) ...[
            ListTile(
              title: Text(item['subject']),
              subtitle: Text("${item['state']} · ${dateText(item['due'])}"),
            ),
            if (item['state'] == 'draft')
              button(
                'Review message',
                () => edit('Review follow-up', {
                  'Subject': item['subject'],
                  'Message': item['body'],
                  'Send at': '',
                }, draft: item['id']),
              ),
            if (['draft', 'queued'].contains(item['state']))
              button(
                'Withdraw follow-up',
                () => load(body: {'action': 'withdraw', 'id': item['id']}),
              ),
          ],
        ]),
        section('Email history', [
          for (final mail in detail['mail'])
            ListTile(
              title: Text(mail['kind']),
              trailing:
                  mail['sent'] == null &&
                      mail['cancelled'] == null &&
                      mail['attempts'] >= 8
                  ? button(
                      'Retry delivery',
                      () => load(
                        body: {'action': 'retry_mail', 'kind': mail['kind']},
                      ),
                    )
                  : null,
              subtitle: Text(
                mail['sent'] != null
                    ? 'Accepted ${dateText(mail['sent'])}'
                    : mail['cancelled'] != null
                    ? 'Cancelled'
                    : '${mail['last_error'] ?? 'Queued'} · Attempts ${mail['attempts']} · ${dateText(mail['due'])}',
              ),
            ),
        ]),
      ],
    ];
  }

  List<Widget> editing() {
    if (editor == 'Set status' || editor == 'Cancel appointment') {
      return [
        Text(
          editor == 'Set status'
              ? 'Set status to ${fields['Status']}?'
              : 'Cancel this appointment and notify attendees?',
        ),
        button(
          'Confirm',
          () => load(
            body: editor == 'Set status'
                ? {'action': 'status', 'value': fields['Status']}
                : {
                    'action': 'cancel',
                    'revision': detail['meeting']['revision'],
                  },
          ),
        ),
        button('Back', () => setState(() => editor = '')),
      ];
    }
    return [
      Text(editor, style: const TextStyle(fontSize: 22)),
      for (final k in fields.keys)
        TextFormField(
          key: ValueKey('$editor-$k'),
          initialValue: fields[k],
          maxLines: k == 'Message'
              ? 12
              : k == 'Available times'
              ? 4
              : null,
          decoration: InputDecoration(
            labelText: label(k),
            helperText: k == 'Available times'
                ? 'One date and time per line, including Z or UTC offset'
                : k == 'Send at'
                ? 'Optional. Include a UTC offset. Leave blank to send on approval.'
                : null,
          ),
          onChanged: (v) => fields[k] = v,
        ),
      if (editor == 'Review follow-up' &&
          detail['briefing']?['outreach_draft'] != null)
        SelectableText(
          'Optional draft paragraph for review and copying:\n${detail['briefing']['outreach_draft']}',
        ),
      button(
        editor == 'Review follow-up'
            ? 'Approve and queue email'
            : editor == 'Offer times'
            ? 'Send scheduling invitation'
            : 'Save',
        submitEdit,
      ),
      button('Back', () => setState(() => editor = '')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark(useMaterial3: true);
    return Theme(
      data: theme,
      child: Material(
        color: theme.colorScheme.surface,
        child: ListView(
          key: ValueKey('$id-$editor'),
          padding: const EdgeInsets.all(18),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error.isNotEmpty)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            ...editor.isNotEmpty
                ? editing()
                : id == null
                ? listing()
                : record(),
          ],
        ),
      ),
    );
  }
}
