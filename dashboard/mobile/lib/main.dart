import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_api.dart';

const orange = Color(0xFFC45120);
const surface = Colors.white;
const canvas = Color(0xFFF6F7F9);
const ink = Color(0xFF202226);
const muted = Color(0xFF70757D);
const line = Color(0xFFE6E8EC);
const healthy = Color(0xFF237650);

ThemeData dashboardTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    fontFamily: 'CupertinoSystemDisplay',
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: orange,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(primary: ink, secondary: orange, onSurface: ink),
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          bodyLarge: base.textTheme.bodyLarge!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: ink,
          ),
          bodyMedium: base.textTheme.bodyMedium!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: ink,
          ),
          titleMedium: base.textTheme.titleMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: ink,
          ),
          labelLarge: base.textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 78,
      titleSpacing: 24,
      titleTextStyle: TextStyle(
        fontFamily: 'CupertinoSystemDisplay',
        fontSize: 23,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      iconColor: muted,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'CupertinoSystemDisplay',
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'CupertinoSystemDisplay',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      elevation: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FounderApp(api: DashboardApi()));
}

class FounderApp extends StatefulWidget {
  final DashboardApi api;
  const FounderApp({super.key, required this.api});
  @override
  State<FounderApp> createState() => _FounderAppState();
}

class _FounderAppState extends State<FounderApp> with WidgetsBindingObserver {
  Timer? timer;
  bool obscured = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.restore();
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!obscured && widget.api.signedIn && !widget.api.loading) {
        widget.api.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => obscured = state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused) widget.api.lock();
    if (state == AppLifecycleState.resumed && widget.api.signedIn) {
      widget.api.refresh();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FindEZ Dashboard',
    debugShowCheckedModeBanner: false,
    theme: dashboardTheme(),
    themeMode: ThemeMode.light,
    builder: (context, child) => MediaQuery(
      // Keep the founder's chosen type weights; retain system text scaling.
      data: MediaQuery.of(context).copyWith(boldText: false),
      child: child!,
    ),
    home: AnimatedBuilder(
      animation: widget.api,
      builder: (context, _) {
        final api = widget.api;
        Widget child;
        if (api.restoring) {
          child = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (api.locked) {
          child = Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 42, color: orange),
                    const SizedBox(height: 20),
                    const Text(
                      'Your dashboard is locked',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: api.unlock,
                      child: const Text('Unlock dashboard'),
                    ),
                    TextButton(
                      onPressed: api.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (!api.signedIn) {
          child = SignIn(api: api);
        } else {
          child = DashboardShell(api: api);
        }
        return Stack(
          children: [
            child,
            if (obscured)
              const Positioned.fill(child: ColoredBox(color: canvas)),
          ],
        );
      },
    ),
  );
}

class SignIn extends StatefulWidget {
  final DashboardApi api;
  const SignIn({super.key, required this.api});
  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final email = TextEditingController(
    text: 'tanyasmritivictorcharles@gmail.com',
  );
  final password = TextEditingController();
  final code = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FindEZ',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.6,
                    ),
                  ),
                  const Text(
                    'Founder dashboard',
                    style: TextStyle(fontSize: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    api.factor != null
                        ? 'Enter the code from your authenticator app.'
                        : 'A private view of your product, customers and operations.',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (!api.configured)
                    const Notice(
                      'The signed release configuration is missing. Install the configured TestFlight build.',
                    )
                  else if (api.factor != null)
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Authenticator code',
                      ),
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onSubmitted: (_) => api.verifyCode(code.text),
                    )
                  else ...[
                    TextField(
                      controller: email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Founder email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 16),
                    if (api.emailCodePending)
                      TextField(
                        controller: code,
                        decoration: const InputDecoration(
                          labelText: 'Email sign-in code',
                        ),
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onSubmitted: (_) =>
                            api.verifyEmailCode(email.text, code.text),
                      )
                    else
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'FindEZ password',
                        ),
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) =>
                            api.signIn(email.text, password.text),
                      ),
                  ],
                  if (api.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        api.error!,
                        style: const TextStyle(color: Color(0xFFB42332)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: api.loading || !api.configured
                          ? null
                          : () => api.factor != null
                                ? api.verifyCode(code.text)
                                : api.emailCodePending
                                ? api.verifyEmailCode(email.text, code.text)
                                : api.signIn(email.text, password.text),
                      child: Text(
                        api.loading
                            ? 'Connecting...'
                            : api.factor != null
                            ? 'Verify code'
                            : 'Open dashboard',
                      ),
                    ),
                  ),
                  if (api.configured && api.factor == null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: api.loading ? null : api.requestEmailCode,
                        child: Text(
                          api.emailCodePending
                              ? 'Send another email code'
                              : 'Email me a sign-in code',
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Founder access only. Your session is stored in the iPhone Keychain.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const destinations = [
  'Overview',
  'Analytics',
  'Revenue',
  'Customers',
  'AI & FIND',
  'Infrastructure',
  'Live Activity',
  'Launch & Growth',
  'Admin & Security',
  'Settings',
  'Issues',
];

class DashboardShell extends StatefulWidget {
  final DashboardApi api;
  const DashboardShell({super.key, required this.api});
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int page = 0;
  bool more = false;
  void go(int index) {
    setState(() {
      page = index;
      more = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = more
        ? PageList(
            children: [
              for (final group in <String, List<int>>{
                'Business': [1, 2],
                'Operations': [4, 5, 6],
                'Company': [7, 8, 9],
              }.entries) ...[
                SectionTitle(group.key),
                Card(
                  child: Column(
                    children: [
                      for (var j = 0; j < group.value.length; j++) ...[
                        if (j > 0) const Divider(indent: 20, endIndent: 20),
                        ListTile(
                          title: Text(destinations[group.value[j]]),
                          trailing: const Icon(Icons.chevron_right, size: 15),
                          onTap: () => go(group.value[j]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          )
        : _page();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              more
                  ? 'More'
                  : page == 0
                  ? 'FindEZ'
                  : destinations[page],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w400),
            ),
            Text(
              api.loading
                  ? 'Refreshing all sources...'
                  : api.error != null
                  ? 'Refresh failed / Previous data'
                  : api.lastSuccess == null
                  ? 'FindEZ founder dashboard'
                  : 'Updated ${clock(api.lastSuccess!.toIso8601String())}  /  Every 60s',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: api.loading ? null : api.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 225,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'FindEZ\nFOUNDER',
                        style: TextStyle(fontSize: 22, color: orange),
                      ),
                    ),
                    for (var i = 0; i < destinations.length; i++)
                      ListTile(
                        selected: page == i,
                        title: Text(destinations[i]),
                        onTap: () => go(i),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (api.loading) const LinearProgressIndicator(minHeight: 2),
                  if (api.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Notice(
                        'Refresh failed. ${api.data == null ? '' : 'Showing the previous synchronized data. '}${api.error}',
                      ),
                    ),
                  Expanded(
                    child: api.data == null
                        ? Center(
                            child: api.loading
                                ? const CircularProgressIndicator()
                                : FilledButton(
                                    onPressed: api.refresh,
                                    child: const Text('Try again'),
                                  ),
                          )
                        : RefreshIndicator(onRefresh: api.refresh, child: body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: more
                  ? 3
                  : page == 10
                  ? 1
                  : page == 3
                  ? 2
                  : page == 0
                  ? 0
                  : 3,
              onDestinationSelected: (i) {
                if (i == 3) {
                  setState(() => more = true);
                } else {
                  go([0, 10, 3][i]);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  label: 'Issues',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Customers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
      floatingActionButton: page == 10 || page == 7
          ? FloatingActionButton(
              tooltip: page == 7 ? 'Add priority' : 'Add issue',
              onPressed: () => addIssue(context, api, task: page == 7),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _page() {
    final api = widget.api, data = api.data!;
    switch (page) {
      case 0:
        return Overview(data: data, go: go);
      case 1:
        return MetricsPage(
          section: section(data, 'analytics'),
          intro:
              'Growth and adoption from real accounts and saved inventory. Activity and retention need event instrumentation.',
          extra: growthChart(data),
        );
      case 2:
        return MetricsPage(
          section: section(data, 'revenue'),
          intro:
              'Payments and subscriptions stay separate from company cash, accounting profit and forecasts.',
        );
      case 3:
        return CustomersPage(api: api, customers: records(data['customers']));
      case 4:
        return MetricsPage(
          section: section(data, 'ai'),
          intro:
              'FIND and the private agent gateway. Quota counters are shown separately from request performance and cost.',
        );
      case 5:
        return InfrastructurePage(data: data);
      case 6:
        return ActivityPage(events: records(data['activity']));
      case 7:
        return PageList(
          children: [
            const Intro(
              'Your next priorities',
              'Add launch checks, bugs, decisions and growth experiments. Nothing is marked complete without evidence.',
            ),
            IssueList(api: api, task: true),
            const Notice(
              'Campaign attribution, acquisition cost and release-provider feeds are not connected. Android release status is not assumed.',
            ),
          ],
        );
      case 8:
        return PageList(
          children: [
            const Intro(
              'Private by design',
              'Access is checked on the server against the founder account. Customer roles never grant founder access.',
            ),
            const Notice(
              'Customer suspension, billing changes, exports and deletion are not enabled in this build. These require reauthentication, explicit confirmation and an audit trail.',
            ),
            const SectionTitle('Administrative history'),
            for (final event in records(data['audit']))
              Card(
                child: ListTile(
                  title: Text(
                    (event['action'] ?? '').toString().replaceAll('_', ' '),
                  ),
                  subtitle: Text(
                    '${stamp(event['at'])}\n${event['outcome']}  |  ${event['target']}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      case 9:
        return PageList(
          children: [
            const Intro(
              'Connections & settings',
              'Data refreshes every 60 seconds while the dashboard is open. Health probes also run on the server every minute.',
            ),
            for (final source in records(data['source_status']))
              Card(
                child: ListTile(
                  title: Text(source['name']),
                  trailing: Text(
                    source['status'],
                    style: TextStyle(
                      color: source['status'] == 'synced'
                          ? const Color(0xFF237650)
                          : orange,
                    ),
                  ),
                ),
              ),
            const Notice(
              'Product events, provider costs, App Store finances, GPU telemetry, backup verification and marketing attribution are not connected. No estimates are displayed as actuals.',
            ),
            const Notice(
              'Session storage: iPhone Keychain, this device only. Returning to the app requires your device unlock. Multifactor sign-in is honored when enabled on your account.',
            ),
            OutlinedButton.icon(
              onPressed: api.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        );
      case 10:
        return PageList(
          children: [
            const Intro(
              'One place for issues',
              'Live monitoring incidents and notes you add. Resolve or reopen items as you work.',
            ),
            IssueList(api: api),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class Overview extends StatelessWidget {
  final Json data;
  final void Function(int) go;
  const Overview({super.key, required this.data, required this.go});
  @override
  Widget build(BuildContext context) {
    final issues =
        records(data['issues'])
            .where((e) => e['status'] != 'resolved' && e['kind'] != 'task')
            .toList()
          ..sort(
            (a, b) => severityRank(
              b['severity'],
            ).compareTo(severityRank(a['severity'])),
          );
    final checks = records(section(data, 'infrastructure')['checks']);
    final users = findMetric(data, 'analytics', 'users', 'Registered users');
    final signups = findMetric(
      data,
      'analytics',
      'signups7',
      'New users in 7 days',
    );
    final tasks = records(
      data['issues'],
    ).where((e) => e['kind'] == 'task' && e['status'] != 'resolved').toList();
    return PageList(
      children: [
        const Intro('Overview', 'Your business, clearly.'),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => go(1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registered users',
                    style: TextStyle(color: muted, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayValue(users),
                    style: TextStyle(
                      fontSize: users['value'] == null ? 24 : 54,
                      height: 1.1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'New in the last 7 days',
                          style: const TextStyle(color: muted, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        displayValue(signups),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        MetricGrid(
          metrics: [
            findMetric(data, 'revenue', 'mrr', 'Monthly recurring revenue'),
            findMetric(data, 'ai', 'chats', 'Tracked Assist uses'),
          ],
          onTap: (m) => go(m['id'] == 'mrr' ? 2 : 4),
        ),
        Row(
          children: [
            const Expanded(child: SectionTitle('Service health')),
            TextButton(onPressed: () => go(5), child: const Text('Details')),
          ],
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < checks.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                HealthTile(check: checks[i], onTap: () => go(5), grouped: true),
              ],
              if (checks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Health checks unavailable',
                    style: TextStyle(color: muted),
                  ),
                ),
            ],
          ),
        ),
        const Text(
          'AI usage is connected. Success rate and quality are not yet measured.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
        Row(
          children: [
            const Expanded(child: SectionTitle('Needs your attention')),
            TextButton(onPressed: () => go(10), child: const Text('View all')),
          ],
        ),
        if (issues.isEmpty)
          const Notice(
            'No open issues reported by connected monitoring. Unconnected sources are not assessed.',
          )
        else
          for (final issue in issues.take(3))
            Card(
              child: ListTile(
                onTap: () => go(10),
                title: Text(issue['title']),
                subtitle: Text(
                  '${issue['severity']}  /  ${stamp(issue['updated_at'])}',
                  style: TextStyle(
                    color: severityColor(issue['severity']),
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 15),
              ),
            ),
        const SectionTitle("Today's priority"),
        Card(
          child: ListTile(
            onTap: () => go(issues.isNotEmpty ? 10 : 7),
            title: Text(
              issues.isNotEmpty
                  ? issues.first['title']
                  : tasks.isNotEmpty
                  ? tasks.first['title']
                  : 'Set your next priority',
            ),
            subtitle: Text(
              issues.isNotEmpty
                  ? 'Highest severity open issue'
                  : tasks.isNotEmpty
                  ? 'From your saved priorities'
                  : 'Add a goal or launch check',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, size: 15),
          ),
        ),
      ],
    );
  }
}

class MetricsPage extends StatelessWidget {
  final Json section;
  final String intro;
  final Widget? extra;
  const MetricsPage({
    super.key,
    required this.section,
    required this.intro,
    this.extra,
  });
  @override
  Widget build(BuildContext context) => PageList(
    children: [
      Text(intro, style: const TextStyle(color: muted, height: 1.5)),
      if (section['note'] != null) Notice(section['note']),
      if (section['unavailable'] == true)
        const Notice('This source could not synchronize. Try refreshing.'),
      MetricCatalog(metrics: records(section['metrics'])),
      ?extra,
    ],
  );
}

class InfrastructurePage extends StatelessWidget {
  final Json data;
  const InfrastructurePage({super.key, required this.data});
  @override
  Widget build(BuildContext context) => PageList(
    children: [
      const Intro(
        'Service health',
        'Direct checks of the self-hosted web app, backend and database. Probe latency measures the health check, not customer API performance.',
      ),
      for (final check in records(section(data, 'infrastructure')['checks']))
        HealthTile(check: check),
      const SectionTitle('Resources & reliability'),
      MetricCatalog(
        metrics: records(section(data, 'infrastructure')['metrics']),
      ),
      const SectionTitle('Recent health probes'),
      if (records(data['monitoring_history']).isEmpty)
        const Notice('Probe history starts when this dashboard is installed.'),
      for (final sample in records(data['monitoring_history']).take(20))
        Card(
          child: ListTile(
            title: Text(stamp(sample['at'])),
            subtitle: Text(
              records(sample['checks'])
                  .map(
                    (c) =>
                        '${c['label']}: ${c['healthy'] == true ? 'healthy' : 'unavailable'}',
                  )
                  .join('\n'),
            ),
          ),
        ),
    ],
  );
}

class CustomersPage extends StatefulWidget {
  final List<Json> customers;
  final DashboardApi api;
  const CustomersPage({super.key, required this.api, required this.customers});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String query = '';
  bool newest = true;
  int limit = 30;
  @override
  Widget build(BuildContext context) {
    final users = widget.customers
        .where(
          (u) => '${u['email']} ${u['id']}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    if (!newest) {
      users.sort(
        (a, b) => a['email'].toString().compareTo(b['email'].toString()),
      );
    }
    return PageList(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search email or user ID',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() {
            query = v;
            limit = 30;
          }),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${users.length} accounts',
                style: const TextStyle(color: muted),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => newest = !newest),
              icon: const Icon(Icons.sort),
              label: Text(newest ? 'Newest first' : 'Email A to Z'),
            ),
          ],
        ),
        const Notice(
          'Last sign-in is shown explicitly. It is not a measurement of last product activity.',
        ),
        if (users.isEmpty)
          const Notice(
            'No matching accounts in the synchronized customer directory.',
          ),
        for (final user in users.take(limit))
          Card(
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerDetail(api: widget.api, userId: user['id']),
                ),
              ),
              title: Text(user['email'], maxLines: 2),
              subtitle: Text(
                '${user['plan']}  |  Joined ${stamp(user['created_at'], dateOnly: true)}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        if (users.length > limit)
          OutlinedButton(
            onPressed: () => setState(() => limit += 30),
            child: const Text('Load more'),
          ),
      ],
    );
  }
}

class CustomerDetail extends StatelessWidget {
  final DashboardApi api;
  final String userId;
  const CustomerDetail({super.key, required this.api, required this.userId});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: api,
    builder: (context, _) {
      final user = records(
        api.data?['customers'],
      ).where((u) => u['id'] == userId).firstOrNull;
      if (user == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Customer')),
          body: const PageList(
            children: [
              Notice(
                'This account is unavailable in the current synchronized directory.',
              ),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: PageList(
          children: [
            Text(
              api.error != null
                  ? 'Refresh failed. Showing the previous synchronized record.'
                  : api.lastSuccess == null
                  ? 'Refreshes every 60 seconds'
                  : 'Updated ${clock(api.lastSuccess!.toIso8601String())} / Every 60s',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            SelectableText(
              user['email'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            for (final entry in {
              'User ID': user['id'],
              'Account created': stamp(user['created_at']),
              'Last sign-in': stamp(user['last_sign_in']),
              'Recorded plan': user['plan'],
              'Account status': user['status'],
              'Platform': user['platform'],
              'Inventory records': user['items'] ?? 'Unavailable',
              'Spaces': user['spaces'] ?? 'Unavailable',
              'Team memberships': user['memberships'] is List
                  ? (user['memberships'] as List).length
                  : 'Unavailable',
            }.entries)
              Card(
                child: ListTile(
                  title: Text(
                    entry.key,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  subtitle: SelectableText(
                    entry.value.toString(),
                    style: const TextStyle(color: ink, fontSize: 16),
                  ),
                ),
              ),
            const Notice(
              'No customer inventory contents, passwords or credentials are shown. Billing history and per-customer feature events are not connected. Account access changes are disabled.',
            ),
          ],
        ),
      );
    },
  );
}

class ActivityPage extends StatefulWidget {
  final List<Json> events;
  const ActivityPage({super.key, required this.events});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String filter = 'All', search = '';
  int limit = 30;
  @override
  Widget build(BuildContext context) {
    final values = widget.events
        .where(
          (e) =>
              (filter == 'All' || e['category'] == filter) &&
              '${e['title']} ${e['detail']}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return PageList(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search activity',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['All', 'Customers', 'Diagnostics'])
              ChoiceChip(
                label: Text(f),
                selected: f == filter,
                onSelected: (_) => setState(() {
                  filter = f;
                  limit = 30;
                }),
              ),
          ],
        ),
        const Notice(
          'Registrations and redacted backend diagnostics. Full product, billing and deployment event streams are not connected. Up to 150 recent events are synchronized.',
        ),
        if (values.isEmpty)
          const Notice('No matching activity in this synchronized window.'),
        for (final e in values.take(limit))
          Card(
            child: ListTile(
              title: Text(e['title']),
              subtitle: Text('${stamp(e['at'])}\n${e['detail']}'),
              isThreeLine: true,
            ),
          ),
        if (values.length > limit)
          OutlinedButton(
            onPressed: () => setState(() => limit += 30),
            child: const Text('Load more'),
          ),
      ],
    );
  }
}

class IssueList extends StatefulWidget {
  final DashboardApi api;
  final bool task;
  const IssueList({super.key, required this.api, this.task = false});
  @override
  State<IssueList> createState() => _IssueListState();
}

class _IssueListState extends State<IssueList> {
  bool resolved = false;
  @override
  Widget build(BuildContext context) {
    final issues = records(widget.api.data?['issues'])
        .where(
          (e) =>
              (e['kind'] == 'task') == widget.task &&
              (resolved || e['status'] != 'resolved'),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include resolved'),
          value: resolved,
          onChanged: (v) => setState(() => resolved = v),
        ),
        if (issues.isEmpty)
          Notice(
            widget.task
                ? 'No saved priorities. Tap + to add your first one.'
                : 'No matching issues. Tap + to record something to investigate.',
          ),
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: severityColor(issue['severity']),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${issue['severity']}  |  ${issue['source']}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      issue['title'],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (issue['description'] != '')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          issue['description'],
                          style: const TextStyle(color: muted, height: 1.5),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      stamp(issue['updated_at']),
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    DropdownButton<String>(
                      value: issue['status'],
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Text('Resolved'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        try {
                          await widget.api.updateIssue(issue['id'], value);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> addIssue(
  BuildContext context,
  DashboardApi api, {
  bool task = false,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => IssueEditor(api: api, task: task),
    ),
  );
}

class IssueEditor extends StatefulWidget {
  final DashboardApi api;
  final bool task;
  const IssueEditor({super.key, required this.api, required this.task});
  @override
  State<IssueEditor> createState() => _IssueEditorState();
}

class _IssueEditorState extends State<IssueEditor> {
  final title = TextEditingController(), details = TextEditingController();
  String severity = 'warning';
  String? error;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.task ? 'New priority' : 'New issue')),
    body: PageList(
      children: [
        TextField(
          controller: title,
          maxLength: 140,
          decoration: const InputDecoration(labelText: 'What needs attention?'),
        ),
        TextField(
          controller: details,
          minLines: 4,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        DropdownButtonFormField<String>(
          initialValue: severity,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const [
            DropdownMenuItem(value: 'info', child: Text('Normal')),
            DropdownMenuItem(value: 'warning', child: Text('Important')),
            DropdownMenuItem(value: 'critical', child: Text('Urgent')),
          ],
          onChanged: (v) => severity = v!,
        ),
        if (error != null) Notice(error!),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (title.text.trim().length < 3) {
                    setState(
                      () => error = 'Add a title with at least 3 characters.',
                    );
                    return;
                  }
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await widget.api.saveIssue(
                      title: title.text.trim(),
                      description: details.text.trim(),
                      severity: severity,
                      kind: widget.task ? 'task' : 'issue',
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        saving = false;
                        error = e.toString();
                      });
                    }
                  }
                },
          child: Text(saving ? 'Saving...' : 'Save'),
        ),
      ],
    ),
  );
}

class MetricCatalog extends StatelessWidget {
  final List<Json> metrics;
  const MetricCatalog({super.key, required this.metrics});
  @override
  Widget build(BuildContext context) {
    final available = metrics.where((m) => m['value'] != null).toList();
    final missing = metrics.where((m) => m['value'] == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (available.isNotEmpty) MetricGrid(metrics: available),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              child: ExpansionTile(
                title: Text('Unavailable metrics (${missing.length})'),
                subtitle: const Text(
                  'Tap to see what still needs a data source.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                children: [
                  for (final m in missing)
                    ListTile(
                      title: Text(m['label']),
                      subtitle: const Text('Unavailable'),
                      onTap: () => metricInfo(context, m),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class MetricGrid extends StatelessWidget {
  final List<Json> metrics;
  final void Function(Json)? onTap;
  const MetricGrid({super.key, required this.metrics, this.onTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
              constraints.maxWidth < 300
          ? 1
          : constraints.maxWidth >= 900
          ? 3
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final m in metrics)
            SizedBox(
              width: width,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      onTap != null ? onTap!(m) : metricInfo(context, m),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Text(
                            m['label'],
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          displayValue(m),
                          style: TextStyle(
                            fontSize: m['value'] == null ? 17 : 34,
                            height: 1.1,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w300,
                            color: m['value'] == null ? muted : ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          m['period'] ?? 'Current',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        if (m['note'] != null && m['note'] != '')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              m['note'],
                              style: const TextStyle(
                                color: orange,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

void metricInfo(BuildContext context, Json metric) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric['label'], style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          Text(
            metric['definition'] ?? '',
            style: const TextStyle(color: muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          Text(
            'Source: ${metric['source']}\nPeriod: ${metric['period']}\nStatus: ${metric['status']}\nRefresh: every 60 seconds\nOwner: FindEZ founder',
            style: const TextStyle(height: 1.8),
          ),
        ],
      ),
    ),
  ),
);

class HealthTile extends StatelessWidget {
  final Json check;
  final VoidCallback? onTap;
  final bool grouped;
  const HealthTile({
    super.key,
    required this.check,
    this.onTap,
    this.grouped = false,
  });
  @override
  Widget build(BuildContext context) {
    final good = check['healthy'] == true;
    final tile = ListTile(
      onTap: onTap,
      title: Text(check['label'], style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        check['latency_ms'] == null
            ? 'Latency unavailable'
            : '${check['latency_ms']} ms probe',
        style: const TextStyle(color: muted, fontSize: 12),
      ),
      trailing: Text(
        good ? 'Healthy' : 'Unavailable',
        style: TextStyle(
          color: good ? healthy : const Color(0xFFB42332),
          fontSize: 13,
        ),
      ),
    );
    return grouped ? tile : Card(child: tile);
  }
}

class PageList extends StatelessWidget {
  final List<Widget> children;
  const PageList({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      for (final child in children)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
    ],
  );
}

class Intro extends StatelessWidget {
  final String title, body;
  const Intro(this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w400,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(color: muted, height: 1.5, fontSize: 15),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  const Notice(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF0F3),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(color: muted, height: 1.5, fontSize: 13),
    ),
  );
}

Json section(Json data, String key) =>
    Map<String, dynamic>.from(data[key] as Map? ?? {});
List<Json> records(dynamic values) => (values as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
Json findMetric(Json data, String source, String id, String label) =>
    records(
      section(data, source)['metrics'],
    ).where((m) => m['id'] == id).firstOrNull ??
    {
      'id': id,
      'label': label,
      'value': null,
      'source': 'Unavailable',
      'status': 'unavailable',
      'period': 'Current',
    };
int severityRank(dynamic value) => value == 'critical'
    ? 3
    : value == 'warning'
    ? 2
    : 1;
Color severityColor(dynamic value) => value == 'critical'
    ? const Color(0xFFB42332)
    : value == 'warning'
    ? orange
    : muted;
String clock(String? value) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  return date == null
      ? 'Unavailable'
      : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String stamp(dynamic value, {bool dateOnly = false}) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return date == null
      ? 'Not recorded'
      : '${date.month}/${date.day}/${date.year}${dateOnly ? '' : '  ${clock(date.toIso8601String())}'}';
}

String displayValue(Json m) {
  final value = m['value'];
  if (value == null) return 'Unavailable';
  if (m['unit'] == 'usd') return '\$${(value as num).toStringAsFixed(2)}';
  if (m['unit'] == 'percent') return '$value%';
  if (m['unit'] != null && m['unit'] != 'count') {
    return '$value ${m['unit'].toString().toUpperCase()}';
  }
  return value.toString();
}

Widget growthChart(Json data) {
  final rows = records(section(data, 'analytics')['growth']);
  if (rows.isEmpty) return const Notice('User growth history is unavailable.');
  final max = rows.fold<num>(
    1,
    (v, r) => (r['count'] as num) > v ? r['count'] : v,
  );
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New accounts by day', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Last 14 days  |  Supabase Auth',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      row['day'].toString().substring(5),
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: row['count'] / max,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(6),
                      color: orange,
                      backgroundColor: const Color(0xFFEEEFF2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(width: 26, child: Text('${row['count']}')),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
