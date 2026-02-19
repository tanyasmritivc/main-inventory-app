import 'package:flutter/material.dart';

import '../../core/ui/glass_card.dart';
import '../auth/auth_page.dart';
import 'onboarding_prefs.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _index = 0;
  String? _persona;

  static const _personas = <String>[
    'Home owner',
    'Student',
    'Small business',
    'Creator / reseller',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    OnboardingPrefs.getPersona().then((value) {
      if (!mounted) return;
      setState(() => _persona = value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    if (next < 0 || next > 5) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _continueToAuth() async {
    await OnboardingPrefs.setCompleted(true);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  Widget _pageShell({required String title, String? subtitle, required Widget child}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_index > 0)
                  IconButton(
                    onPressed: () => _goTo(_index - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            Expanded(child: child),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_index > 0)
                  OutlinedButton(
                    onPressed: () => _goTo(_index - 1),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (_index < 5) {
                      _goTo(_index + 1);
                    } else {
                      _continueToAuth();
                    }
                  },
                  child: Text(_index < 5 ? 'Next' : 'Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _screen1() {
    return _pageShell(
      title: 'What best describes you?',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _personas
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(() => _persona = _persona == p ? null : p);
                          await OnboardingPrefs.setPersona(_persona);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p,
                            style: TextStyle(
                              color: _persona == p ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Optional. You can skip this.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }

  Widget _screen2() {
    return _pageShell(
      title: 'Add anything to FindEZ',
      subtitle: 'Photos of items\nLists\nJust tell us what you own',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 34, color: Colors.white.withValues(alpha: 0.80)),
                const SizedBox(height: 10),
                Text(
                  'Drop a photo here',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Demo only',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.handyman_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hammer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Garage',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '3',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _screen3() {
    return _pageShell(
      title: 'We’ll organize everything for you',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Garage',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                ),
                const SizedBox(height: 10),
                const _DemoRow(label: 'Hammer', trailing: '3'),
                const _DemoRow(label: 'Drill'),
                const _DemoRow(label: 'Extension cord'),
                const SizedBox(height: 16),
                Text(
                  'Kitchen',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                ),
                const SizedBox(height: 10),
                const _DemoRow(label: 'Blender'),
                const _DemoRow(label: 'Measuring cups'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Demo preview. Nothing is saved yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }

  Widget _screen4() {
    return _pageShell(
      title: 'Find anything about your stuff',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChatBubble(text: 'What do I need to restock?', isUser: true),
                const SizedBox(height: 12),
                _ChatBubble(text: 'Where is my drill?', isUser: true),
                const SizedBox(height: 12),
                _ChatBubble(text: 'What can I sell?', isUser: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Preview only. Nothing is sent yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }

  Widget _screen5() {
    return _pageShell(
      title: 'Never forget what matters',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _DemoAlert(icon: Icons.inventory_2_outlined, title: 'Low stock alert', subtitle: 'Batteries running low'),
                const SizedBox(height: 12),
                const _DemoAlert(icon: Icons.verified_outlined, title: 'Warranty reminder', subtitle: 'Laptop coverage expires soon'),
                const SizedBox(height: 12),
                const _DemoAlert(icon: Icons.search_outlined, title: 'Lost item reminder', subtitle: 'Haven’t seen your drill in a while'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Preview only. No notifications or permissions yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }

  Widget _screen6() {
    return _pageShell(
      title: 'Built for people who hate managing inventory',
      subtitle: 'Private\nSecure\nYours',
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TrustRow(icon: Icons.lock_outline_rounded, label: 'Private'),
                const SizedBox(height: 12),
                _TrustRow(icon: Icons.shield_outlined, label: 'Secure'),
                const SizedBox(height: 12),
                _TrustRow(icon: Icons.person_outline_rounded, label: 'Yours'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const BouncingScrollPhysics(),
        children: [
          _screen1(),
          _screen2(),
          _screen3(),
          _screen4(),
          _screen5(),
          _screen6(),
        ],
      ),
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bg = isUser ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.06);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _DemoAlert extends StatelessWidget {
  const _DemoAlert({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.80)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
