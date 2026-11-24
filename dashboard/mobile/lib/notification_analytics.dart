import 'package:flutter/material.dart';
import 'dashboard_api.dart';

class NotificationAnalytics extends StatefulWidget {
  const NotificationAnalytics({super.key, required this.api});
  final DashboardApi api;
  @override
  State<NotificationAnalytics> createState() => _NotificationAnalyticsState();
}

class _NotificationAnalyticsState extends State<NotificationAnalytics> {
  late Future<Json> report = widget.api.notificationAnalytics();
  static const labels = {
    'selected': 'Selected',
    'scheduled': 'Scheduled',
    'submitted': 'APNs attempts',
    'accepted': 'Accepted by Apple',
    'measurable_accepted': 'Accepted on tap-reporting clients',
    'rejected': 'Rejected attempts',
    'unknown': 'Unknown outcomes',
    'app_reported_received': 'App-reported receipts',
    'taps': 'Push taps',
    'destinations': 'Destination visits',
    'started': 'Actions started',
    'completed': 'Completed workflows',
    'action_units': 'Completed actions',
    'attributed_additions': 'Additions attributed to Add or Scan',
    'additions_after_interaction':
        'Additions within 24 hours of any interaction',
    'tap_rate': 'Tap-through',
    'conversion_rate': 'Push-to-action conversion',
    'completion_rate': 'Action completion',
    'subsequent_disablements': 'Subsequent settings disabled',
  };
  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: report,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(
          child: TextButton(
            onPressed: () => setState(() {
              report = widget.api.notificationAnalytics();
            }),
            child: const Text('Notification analytics unavailable. Retry'),
          ),
        );
      }
      final data = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Last 30 days')),
              IconButton(
                tooltip: 'Refresh notification analytics',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {
                  report = widget.api.notificationAnalytics();
                }),
              ),
            ],
          ),
          Text(
            data['experiment_enabled'] == true
                ? 'Add Item copy experiment enabled'
                : 'Add Item copy experiment off',
          ),
          const Text(
            'Tap-through and conversion use Apple-accepted pushes on clients that can report taps. Conversion requires a tap and a completed workflow. Completion uses started workflows.',
          ),
          for (final row in (data['groups'] as List).cast<Map>())
            Card(
              child: ExpansionTile(
                title: Text(
                  [
                    row['category'],
                    if (row['variant'] != null) row['variant'],
                  ].join(' · '),
                ),
                initiallyExpanded: row['category'] == 'All categories',
                children: [
                  for (final entry in labels.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.value),
                      trailing: Text(
                        row[entry.key] == null
                            ? '—'
                            : '${row[entry.key]}${entry.key.endsWith('_rate') ? '%' : ''}',
                      ),
                    ),
                ],
              ),
            ),
          Card(
            child: ExpansionTile(
              title: const Text('Observed notification settings disabled'),
              children: [
                for (final e in (data['disablements'] as Map).entries)
                  ListTile(
                    title: Text(e.key.toString()),
                    trailing: Text(e.value.toString()),
                  ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('Accepted pushes per account'),
              children: [
                for (final row
                    in (data['account_frequency'] as List).cast<Map>())
                  ListTile(
                    title: Text(row['account'].toString()),
                    trailing: Text(row['accepted'].toString()),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
