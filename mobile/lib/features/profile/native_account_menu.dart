import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/account_deletion.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/appearance_controller.dart';
import '../../core/external_links.dart';
import '../../core/inventory_cache.dart';
import '../../core/profile_store.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/native_presentation.dart';
import '../notifications/notifications_page.dart';
import 'memory_page.dart';
import 'privacy_policy_page.dart';
import 'profile_editor_page.dart';
import 'terms_of_service_page.dart';

Future<void> showNativeAccountMenu(
  BuildContext context, {
  required ApiClient api,
  required ProfileStore profile,
}) async {
  final appearance = AppearanceScope.maybeOf(context);
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  if (appearance != null) await appearance.load();
  if (!context.mounted) return;
  var confirm = prefs.getBool('confirm_before_save') ?? false;
  Map<String, dynamic> row(
    String id,
    String title,
    String symbol, {
    bool disclosure = true,
  }) => {'id': id, 'title': title, 'symbol': symbol, 'disclosure': disclosure};
  Map<String, dynamic> model() => !context.mounted
      ? {}
      : {
          'title': 'Settings',
          'textSizeFactor':
              (appearance?.textSize ?? AppTextSize.standard).factor,
          'large': true,
          'dark': appearance?.themeMode == ThemeMode.system
              ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
              : appearance == null
              ? Theme.of(context).brightness == Brightness.dark
              : appearance.themeMode == ThemeMode.dark,
          'sections': [
            {
              'rows': [
                {
                  ...row(
                    'profile',
                    profile.name.isEmpty ? 'Your profile' : profile.name,
                    'person.crop.circle',
                  ),
                  'subtitle': 'Edit profile',
                },
                row('notifications', 'Notifications', 'bell'),
              ],
            },
            {
              'title': 'Preferences',
              'rows': [
                if (appearance != null)
                  {
                    ...row(
                      'appearance',
                      'Appearance',
                      'circle.lefthalf.filled',
                    ),
                    'subtitle':
                        '${appearance.themeMode.name} · ${appearance.textSize.label} text',
                    'children': {
                      'pageID': 'appearance',
                      'textSizeFactor': appearance.textSize.factor,
                      'title': 'Appearance',
                      'sections': [
                        {
                          'title': 'Theme',
                          'rows': [
                            for (final mode in ThemeMode.values)
                              {
                                'id': 'theme:${mode.name}',
                                'title': switch (mode) {
                                  ThemeMode.system => 'System',
                                  ThemeMode.light => 'Light',
                                  ThemeMode.dark => 'Dark',
                                },
                                'checked': appearance.themeMode == mode,
                                'close': false,
                              },
                          ],
                          'footer': 'System follows your phone\'s appearance.',
                        },
                        {
                          'title': 'Text size',
                          'rows': [
                            for (final size in AppTextSize.values)
                              {
                                'id': 'size:${size.name}',
                                'title': size.label,
                                'checked': appearance.textSize == size,
                                'close': false,
                              },
                          ],
                          'footer':
                              'Text sizes also follow your phone\'s accessibility settings.',
                        },
                      ],
                    },
                  },
                row('memory', 'Personalization and memory', 'brain'),
              ],
            },
            {
              'title': 'Scanning',
              'footer': 'Review AI results before saving.',
              'rows': [
                {
                  'id': 'scan',
                  'title': 'Confirm before saving',
                  'value': confirm,
                  'close': false,
                },
              ],
            },
            {
              'title': 'Support',
              'rows': [
                row('feedback', 'Send feedback', 'envelope', disclosure: false),
                row(
                  'problem',
                  'Report a problem',
                  'ladybug',
                  disclosure: false,
                ),
              ],
            },
            {
              'title': 'Legal',
              'rows': [
                row('privacy', 'Privacy Policy', 'hand.raised'),
                row('terms', 'Terms of Service', 'doc.text'),
              ],
            },
            {
              'title': 'Account',
              'rows': [
                row(
                  'signout',
                  'Sign out',
                  'rectangle.portrait.and.arrow.right',
                  disclosure: false,
                ),
                {
                  ...row(
                    'delete',
                    'Delete account',
                    'trash',
                    disclosure: false,
                  ),
                  'destructive': true,
                  'confirmation': {
                    'title': 'Delete account?',
                    'message':
                        'This permanently deletes your account and data. This cannot be undone.',
                    'confirmLabel': 'Delete',
                    'destructive': true,
                  },
                },
              ],
            },
          ],
        };
  while (true) {
    if (!context.mounted) return;
    api.assertCurrentContext();
    final selected = await NativePresentation.show(
      context,
      model: model(),
      onAction: (id, value) async {
        if (!context.mounted) return {};
        try {
          api.assertCurrentContext();
          if (id == 'scan' && value != null) {
            if (!await prefs.setBool('confirm_before_save', value)) {
              throw StateError('Preference was not saved');
            }
            confirm = value;
          } else if (id.startsWith('theme:') && appearance != null) {
            if (!await appearance.setThemeMode(
              ThemeMode.values.byName(id.substring(6)),
            )) {
              return {
                ...model(),
                'error': appearance.error ?? 'Please try again.',
              };
            }
          } else if (id.startsWith('size:') && appearance != null) {
            if (!await appearance.setTextSize(
              AppTextSize.values.byName(id.substring(5)),
            )) {
              return {
                ...model(),
                'error': appearance.error ?? 'Please try again.',
              };
            }
          }
          return model();
        } catch (error) {
          return {...model(), 'error': describeError(error).$1};
        }
      },
    );
    if (!context.mounted || selected == null) return;
    if (selected['error'] is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(selected['error'] as String)));
      return;
    }
    api.assertCurrentContext();
    final action = selected['action'];
    late Widget page;
    switch (action) {
      case 'profile':
        page = Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ProfileEditorPage(api: api, store: profile),
        );
      case 'notifications':
        page = NotificationsPage(api: api);
      case 'memory':
        page = MemoryPage(api: api);
      case 'privacy':
        page = const PrivacyPolicyPage();
      case 'terms':
        page = const TermsOfServicePage();
      case 'feedback':
      case 'problem':
        final opened = await tryOpenExternalUrl(
          Uri(
            scheme: 'mailto',
            path: 'info@findez.ai',
            queryParameters: {
              'subject': action == 'problem'
                  ? 'FindEZ Bug Report'
                  : 'FindEZ Feedback',
              'body': 'Hi FindEZ team,\n\n',
            },
          ),
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email us at info@findez.ai')),
          );
        }
        return;
      case 'signout':
      case 'delete':
        try {
          if (action == 'delete') {
            await requestAccountDeletion();
            InventoryCache.clear();
          }
          await PushNotifications.stop();
          await Supabase.instance.client.auth.signOut();
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
          }
        }
        return;
      default:
        return;
    }
    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
      if (!context.mounted) return;
      api.assertCurrentContext();
      if (action == 'profile') await profile.load(force: true);
    }
  }
}
