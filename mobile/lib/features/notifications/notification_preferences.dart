import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/appearance_controller.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/native_presentation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Uses the existing UIKit grouped-sheet renderer without changing Settings.
class NotificationPreferencesController {
  NotificationPreferencesController(this.api) : account = api.accountId;
  final ApiClient api;
  final String? account;
  Map<String, dynamic>? preferences;
  List<String> timezones = [];
  String permission = 'notDetermined';
  String? error;
  bool busy = false;
  bool active = true;
  bool get current => active && account != null && api.accountId == account;

  Future<void> load() async {
    if (!current) return;
    final result = await api.getNotificationPreferences();
    final status = await PushNotifications.authorizationStatus();
    if (!current) return;
    final data = Map<String, dynamic>.from(result['preferences'] as Map);
    if (data['revision'] is! int) {
      throw const FormatException('Preferences could not be loaded.');
    }
    preferences = data;
    timezones = (result['timezones'] as List? ?? [])
        .whereType<String>()
        .toList();
    permission = status;
    error = null;
  }

  Future<void> perform(String id, bool? value) async {
    if (!current || busy) return;
    busy = true;
    error = null;
    try {
      if (id == 'load' || id == 'refresh') {
        await load();
        return;
      }
      if (id == 'phone-settings') {
        if (!await launchUrl(Uri.parse('app-settings:'))) {
          error = 'Open iPhone Settings → Notifications → FindEZ.';
        }
        return;
      }
      final saved = preferences;
      if (saved == null) return;
      final changes = <String, dynamic>{};
      if (id.startsWith('toggle:') && value != null) {
        final key = id.substring(7);
        if (!{
          'push_enabled',
          'in_app_enabled',
          'quiet_enabled',
          'inventory_alerts',
          'capture_reminders',
          'show_details',
        }.contains(key)) {
          return;
        }
        changes[key] = value;
      } else if (id.startsWith('timezone:')) {
        final zone = id.substring(9);
        if (!timezones.contains(zone)) return;
        changes['timezone'] = zone;
      } else if (id.startsWith('quiet_start:') || id.startsWith('quiet_end:')) {
        final parts = id.split(':');
        final minutes = int.tryParse(parts.last);
        if (minutes == null || minutes < 0 || minutes > 1439) return;
        changes[parts.first] = minutes;
      } else if (id.startsWith('pause:')) {
        final days = int.tryParse(id.substring(6));
        if (![0, 1, 7].contains(days)) return;
        changes['paused_until'] = days == 0
            ? null
            : DateTime.now()
                  .toUtc()
                  .add(Duration(days: days!))
                  .toIso8601String();
      }
      if (changes.isEmpty || !current) return;
      final result = await api.updateNotificationPreferences(
        saved['revision'] as int,
        changes,
      );
      if (!current) return;
      preferences = Map<String, dynamic>.from(result['preferences'] as Map);
      if (changes['push_enabled'] == true) {
        final allowed = await PushNotifications.requestPermissionIfNeeded();
        if (!current) return;
        if (allowed) await PushNotifications.registerIfAuthorized(api);
        permission = await PushNotifications.authorizationStatus();
      }
    } catch (e) {
      // Reload on a revision conflict or uncertain write; never pretend saved.
      final message = describeError(e).$1;
      try {
        await load();
      } catch (_) {
        /* Keep last confirmed values. */
      }
      if (current) error = message;
    } finally {
      busy = false;
    }
  }

  Map<String, dynamic> model({double textSizeFactor = 1}) {
    final p = preferences;
    Map<String, dynamic> toggle(String key, String title) => {
      'id': 'toggle:$key',
      'title': title,
      'value': p?[key] == true,
      'close': false,
    };
    String time(int minute) =>
        '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
    Map<String, dynamic> timeRow(String key, String title) => {
      'id': key,
      'title': title,
      'subtitle': time(p![key] as int),
      'children': {
        'pageID': key,
        'title': title,
        'textSizeFactor': textSizeFactor,
        'sections': [
          {
            'rows': [
              for (var m = 0; m < 1440; m += 15)
                {
                  'id': '$key:$m',
                  'title': time(m),
                  'checked': p[key] == m,
                  'close': false,
                },
            ],
          },
        ],
      },
    };
    return {
      'title': 'Notification preferences',
      'large': true,
      'textSizeFactor': textSizeFactor,
      'load': p == null && error == null,
      'loading': p == null && error == null,
      if (error != null) 'error': error,
      'sections': [
        if (p == null)
          {
            'rows': [
              {'id': 'load', 'title': 'Try again', 'close': false},
            ],
          }
        else ...[
          {
            'rows': [
              toggle('push_enabled', 'Phone alerts'),
              toggle('in_app_enabled', 'In-app notifications'),
              if (PushNotifications.supported)
                {
                  'id': 'phone-settings',
                  'title': 'iPhone notification settings',
                  'subtitle':
                      [
                        'authorized',
                        'provisional',
                        'ephemeral',
                      ].contains(permission)
                      ? 'Allowed by iOS'
                      : permission == 'denied'
                      ? 'Off in iPhone Settings'
                      : 'Permission not requested',
                  'close': false,
                },
            ],
            'footer':
                'Up to 2 alerts per day and 5 per week. Only one noncritical alert in 24 hours.',
          },
          {
            'title': 'Alerts',
            'rows': [
              toggle('inventory_alerts', 'Inventory alerts'),
              toggle('capture_reminders', 'Photo review reminders'),
            ],
            'footer':
                'Recorded stock changes and saved photos waiting for review.',
          },
          {
            'title': 'Quiet hours',
            'rows': [
              toggle('quiet_enabled', 'Quiet hours'),
              if (p['quiet_enabled'] == true) ...[
                timeRow('quiet_start', 'From'),
                timeRow('quiet_end', 'Until'),
              ],
              {
                'id': 'timezone',
                'title': 'Timezone',
                'subtitle': p['timezone'],
                'children': {
                  'pageID': 'timezone',
                  'title': 'Timezone',
                  'search': true,
                  'searchPlaceholder': 'Search timezones',
                  'textSizeFactor': textSizeFactor,
                  'sections': [
                    {
                      'rows': [
                        for (final zone in timezones)
                          {
                            'id': 'timezone:$zone',
                            'title': zone.replaceAll('_', ' '),
                            'checked': p['timezone'] == zone,
                            'close': false,
                          },
                      ],
                    },
                  ],
                },
              },
            ],
            'footer':
                'All alerts respect quiet hours, including low-stock alerts.',
          },
          {
            'title': 'Privacy',
            'rows': [toggle('show_details', 'Show details on lock screen')],
            'footer':
                'Off keeps inventory names and quantities out of phone alerts.',
          },
          {
            'title': 'Pause phone alerts',
            'rows': [
              {'id': 'pause:1', 'title': 'For 1 day', 'close': false},
              {'id': 'pause:7', 'title': 'For 7 days', 'close': false},
              if (p['paused_until'] != null)
                {'id': 'pause:0', 'title': 'Resume alerts', 'close': false},
            ],
            if (p['paused_until'] != null)
              'footer':
                  'Paused until ${DateTime.tryParse(p['paused_until'].toString())?.toLocal() ?? p['paused_until']}',
          },
          {
            'footer':
                'Weekly recaps, cleanup insights, re-engagement and scheduled reminders are not available yet. They remain off.',
            'rows': [],
          },
        ],
      ],
    };
  }
}

Future<void> showNotificationPreferences(
  BuildContext context,
  ApiClient api,
) async {
  final controller = NotificationPreferencesController(api);
  final factor =
      (AppearanceScope.maybeOf(context)?.textSize ?? AppTextSize.standard)
          .factor;
  try {
    if (usesNativePresentation) {
      await NativePresentation.show(
        context,
        model: controller.model(textSizeFactor: factor),
        onAction: (id, value) async {
          await controller.perform(id, value);
          return controller.current
              ? controller.model(textSizeFactor: factor)
              : {'title': 'Notifications', 'sections': []};
        },
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PreferencePage(controller: controller),
        ),
      );
    }
  } finally {
    controller.active = false;
  }
}

class _PreferencePage extends StatefulWidget {
  const _PreferencePage({required this.controller});
  final NotificationPreferencesController controller;
  @override
  State<_PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<_PreferencePage> {
  @override
  void initState() {
    super.initState();
    _act('load', null);
  }

  Future<void> _act(String id, bool? value) async {
    final future = widget.controller.perform(id, value);
    if (mounted) setState(() {});
    await future;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: ListView(
        children: [
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(c.error!)),
          for (final section in c.model()['sections'] as List)
            if ((section['rows'] as List? ?? []).isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(section['footer'] as String? ?? ''),
              )
            else
              CupertinoListSection.insetGrouped(
                header: section['title'] == null
                    ? null
                    : Text(section['title'] as String),
                footer: section['footer'] == null
                    ? null
                    : Text(section['footer'] as String),
                children: [
                  for (final row in section['rows'] as List? ?? [])
                    CupertinoListTile(
                      title: Text(row['title'] as String),
                      subtitle: row['subtitle'] == null
                          ? null
                          : Text(row['subtitle'] as String),
                      trailing: row['value'] is bool
                          ? CupertinoSwitch(
                              value: row['value'] as bool,
                              onChanged: c.busy
                                  ? null
                                  : (v) => _act(row['id'] as String, v),
                            )
                          : null,
                      onTap: c.busy || row['value'] is bool
                          ? null
                          : () async {
                              final child = row['children'];
                              if (child is Map) {
                                final choices =
                                    ((child['sections'] as List).first
                                            as Map)['rows']
                                        as List;
                                final id = await showModalBottomSheet<String>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) => SafeArea(
                                    child: SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          .7,
                                      child: ListView(
                                        children: [
                                          for (final choice in choices)
                                            ListTile(
                                              title: Text(
                                                choice['title'] as String,
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                choice['id'] as String,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                if (id != null) await _act(id, null);
                              } else {
                                await _act(row['id'] as String, null);
                              }
                            },
                    ),
                ],
              ),
        ],
      ),
    );
  }
}
