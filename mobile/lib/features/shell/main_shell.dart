import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme_controller.dart';
import '../../core/inventory_cache.dart';
import '../../core/ui/glass_card.dart';
import '../activity/activity_page.dart';
import '../documents/documents_page.dart';
import '../home/home_page.dart';
import '../inventory/inventory_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/terms_of_service_page.dart';
import '../scan/scan_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  int _inventoryRefreshToken = 0;

  final List<Widget?> _tabs = List<Widget?>.filled(5, null);

  HomePage _buildHomeTab() {
    return HomePage(
      api: widget.api,
      onOpenScan: () {
        setState(() {
          _ensureTabBuilt(1);
          _index = 1;
        });
      },
      onOpenSpaces: () {
        setState(() {
          _ensureTabBuilt(2);
          _index = 2;
        });
      },
      onInventoryMutated: () {
        setState(() {
          _inventoryRefreshToken++;
          _tabs[0] = _buildHomeTab();
          _tabs[2] = null;
        });
        _ensureTabBuilt(2);
        unawaited(_prefetchInventoryCache());
      },
    );
  }

  Future<void> _prefetchInventoryCache() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;

      final resp = await supabase
          .from('items')
          .select('item_id,name,category,quantity,location,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(250);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();
      InventoryCache.setItems(items);
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void initState() {
    super.initState();
    widget.api.warmupAi();
    _tabs[0] = _buildHomeTab();
    unawaited(_prefetchInventoryCache());
  }

  void _ensureTabBuilt(int i) {
    if (_tabs[i] != null) return;
    switch (i) {
      case 1:
        _tabs[i] = ScanPage(
          api: widget.api,
          onSaved: () {
            setState(() {
              _inventoryRefreshToken++;
              _tabs[0] = _buildHomeTab();
              _tabs[2] = null;
            });
            _ensureTabBuilt(2);
            unawaited(_prefetchInventoryCache());
          },
        );
        return;
      case 2:
        _tabs[i] = InventoryPage(
          api: widget.api,
          refreshToken: _inventoryRefreshToken,
        );
        return;
      case 3:
        final Type _ = DocumentsPage;
        _tabs[i] = ActivityPage(api: widget.api);
        return;
      case 4:
        _tabs[i] = const _ProfilePage();
        return;
      case 0:
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(
          5,
          (i) => _tabs[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _ensureTabBuilt(i);
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.center_focus_strong_outlined), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Spaces'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ProfileControlCenter extends StatefulWidget {
  const _ProfileControlCenter();

  @override
  State<_ProfileControlCenter> createState() => _ProfileControlCenterState();
}

class _ProfileControlCenterState extends State<_ProfileControlCenter> {
  static const _kNotificationsEnabled = 'notifications_enabled';
  static const _kLowStockAlerts = 'profile.low_stock_alerts';
  static const _kSmartReminders = 'profile.smart_reminders';
  static const _kThemeMode = 'profile.theme_mode';
  static const _kAccent = 'profile.accent_color';
  static const _kAccentColor = 'accent_color';

  bool _lowStockAlerts = true;
  bool _smartReminders = true;
  String _themeMode = 'system';
  String _accent = 'purple';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _lowStockAlerts = prefs.getBool(_kNotificationsEnabled) ?? prefs.getBool(_kLowStockAlerts) ?? true;
        _smartReminders = prefs.getBool(_kSmartReminders) ?? true;
        _themeMode = prefs.getString(AppThemeController.kThemeKey) ?? prefs.getString(_kThemeMode) ?? 'system';
        _accent = prefs.getString(_kAccentColor) ?? prefs.getString(_kAccent) ?? 'purple';
      });
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _setBool(String key, bool value) async {
    setState(() {
      if (key == _kLowStockAlerts || key == _kNotificationsEnabled) {
        _lowStockAlerts = value;
      }
      if (key == _kSmartReminders) _smartReminders = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    await _setBool(_kNotificationsEnabled, value);
  }

  Future<void> _toggleLowStockAlerts(bool next) async {
    if (!next) {
      await _setNotificationsEnabled(false);
      return;
    }

    try {
      final status = await Permission.notification.request();
      if (!mounted) return;
      if (status.isGranted) {
        await _setNotificationsEnabled(true);
        return;
      }

      await _setNotificationsEnabled(false);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: const Text('Enable notifications in settings to receive alerts'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      await _setNotificationsEnabled(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to request notification permission.')),
      );
    }
  }

  Future<void> _setString(String key, String value) async {
    setState(() {
      if (key == _kThemeMode) _themeMode = value;
      if (key == _kAccent) _accent = value;
      if (key == _kAccentColor) _accent = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _applyTheme(String raw) async {
    final v = raw.trim().toLowerCase();
    final mode = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    setState(() => _themeMode = v);
    await AppThemeController.instance.setThemeMode(mode);
  }

  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
          fontWeight: FontWeight.w600,
        );
  }

  Widget _statRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  ChoiceChip _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: Colors.white.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: selected ? 0.95 : 0.78),
      ),
      side: BorderSide(
        color: Colors.white.withValues(alpha: selected ? 0.18 : 0.10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = InventoryCache.items;
    final itemsTracked = items.length;

    final locations = <String>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      locations.add(loc.toLowerCase());
    }
    final spaces = locations.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Inventory', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statRow(label: 'Items tracked', value: '$itemsTracked'),
              const Divider(height: 1),
              _statRow(label: 'Spaces', value: '$spaces'),
              const Divider(height: 1),
              _statRow(label: 'Scans this week', value: '0'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Notifications', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                value: _lowStockAlerts,
                onChanged: (v) => unawaited(_toggleLowStockAlerts(v)),
                title: const Text('Low stock alerts'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                value: _smartReminders,
                onChanged: (v) => unawaited(_setBool(_kSmartReminders, v)),
                title: const Text('Smart reminders'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Appearance', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choiceChip(
                    label: 'System',
                    selected: _themeMode == 'system',
                    onTap: () => unawaited(_applyTheme('system')),
                  ),
                  _choiceChip(
                    label: 'Light',
                    selected: _themeMode == 'light',
                    onTap: () => unawaited(_applyTheme('light')),
                  ),
                  _choiceChip(
                    label: 'Dark',
                    selected: _themeMode == 'dark',
                    onTap: () => unawaited(_applyTheme('dark')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Accent color',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choiceChip(
                    label: 'Purple',
                    selected: _accent == 'purple',
                    onTap: () => unawaited(_setString(_kAccentColor, 'purple')),
                  ),
                  _choiceChip(
                    label: 'Blue',
                    selected: _accent == 'blue',
                    onTap: () => unawaited(_setString(_kAccentColor, 'blue')),
                  ),
                  _choiceChip(
                    label: 'Green',
                    selected: _accent == 'green',
                    onTap: () => unawaited(_setString(_kAccentColor, 'green')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSupportSection extends StatelessWidget {
  const _ProfileSupportSection();

  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
          fontWeight: FontWeight.w600,
        );
  }

  Future<void> _launchEmail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'vinodrexfms@ai-robots.co',
      queryParameters: <String, String>{
        'subject': subject,
      },
    );
    try {
      final can = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (!can) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email app.')),
        );
        return;
      }

      final ok = await launchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email app.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Support', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Send feedback'),
                onTap: () => unawaited(_launchEmail(context, 'FindEZ Feedback')),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report a problem'),
                onTap: () => unawaited(_launchEmail(context, 'FindEZ Issue Report')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF0F172A),
        Color(0xFF020617),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    String emailFallbackName() {
      final e = email.trim();
      if (e.isEmpty) return '—';
      final at = e.indexOf('@');
      if (at <= 0) return e;
      return e.substring(0, at);
    }

    Future<String?> loadFirstName() async {
      if (userId.isEmpty) return null;
      try {
        final res = await Supabase.instance.client.from('profiles').select('first_name').eq('id', userId).maybeSingle();
        final first = (res?['first_name'] as String?)?.trim();
        return (first != null && first.isNotEmpty) ? first : null;
      } catch (e) {
        return null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Text(
            'Account',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Signed in as',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: loadFirstName(),
                      builder: (context, snap) {
                        final name = (snap.data != null && (snap.data ?? '').isNotEmpty)
                            ? snap.data!
                            : emailFallbackName();
                        return Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.1,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ProfileControlCenter(),
          const SizedBox(height: 16),
          Text(
            'Actions',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ProfileSupportSection(),
          const SizedBox(height: 16),
          Text(
            'Legal',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                      child: const Text('Privacy Policy'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServicePage(),
                          ),
                        );
                      },
                      child: const Text('Terms of Service'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'To delete your account and all associated data,\nemail us at vinodrexfms@ai-robots.co\nfrom your registered email address.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                ),
          ),
          ],
        ),
      ),
    );
  }
}
