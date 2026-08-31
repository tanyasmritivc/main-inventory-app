import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});
  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _steps = [
    (
      'Create your first Space',
      'Spaces keep items grouped by where they actually belong.',
    ),
    (
      'Add your first item',
      'Enter it manually, scan its barcode, or extract it from a photo.',
    ),
    ('Find it again', 'Search your inventory or ask Assist where an item is.'),
  ];

  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingPrefs.setPostSignupPending(false);
    await OnboardingPrefs.setCompleted(true);
    if (mounted) widget.onFinished?.call();
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'FindEZ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: 3,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[index].$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _steps[index].$2,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _ProductPreview(page: index)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? const Color(0xFF7CA2E4)
                              : const Color(0xFF3A3A3C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7CA2E4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _finishing
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _page == 2 ? 'Open FindEZ' : 'Continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 0.7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 13),
            child: Row(
              children: [
                Text(
                  page == 0
                      ? 'Inventory'
                      : page == 1
                      ? 'Workshop'
                      : 'Assist',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (page < 2)
                  const Icon(
                    Icons.add_circle_rounded,
                    color: Color(0xFF7CA2E4),
                    size: 22,
                  ),
                if (page == 2)
                  const Icon(
                    Icons.add_comment_outlined,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF242426)),
          Expanded(
            child: switch (page) {
              0 => const _SpacesPreview(),
              1 => const _AddPreview(),
              _ => const _AssistPreview(),
            },
          ),
          _TabPreview(activePage: page),
        ],
      ),
    );
  }
}

class _SpacesPreview extends StatelessWidget {
  const _SpacesPreview();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: const [
        _SpaceCard(
          name: 'Workshop',
          detail: 'Personal Space',
          icon: Icons.folder_rounded,
        ),
        _SpaceCard(
          name: 'Electronics',
          detail: 'Personal Space',
          icon: Icons.folder_rounded,
        ),
        _SpaceCard(
          name: 'New Space',
          detail: 'Tap to create',
          icon: Icons.add_circle_outline_rounded,
          muted: true,
        ),
      ],
    ),
  );
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({
    required this.name,
    required this.detail,
    required this.icon,
    this.muted = false,
  });
  final String name;
  final String detail;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x18FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: muted ? const Color(0xFF8E8E93) : const Color(0xFF7CA2E4),
          size: 28,
        ),
        const Spacer(),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted ? const Color(0xFFAEAEB2) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
        ),
      ],
    ),
  );
}

class _AddPreview extends StatelessWidget {
  const _AddPreview();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
    physics: const NeverScrollableScrollPhysics(),
    children: const [
      Text(
        'ADD AN ITEM',
        style: TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      SizedBox(height: 10),
      _ActionRow(
        icon: Icons.edit_outlined,
        title: 'Manual Entry',
        subtitle: 'Name, quantity, and location',
      ),
      _ActionRow(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Scan Barcode',
        subtitle: 'Identify a labeled item',
      ),
      _ActionRow(
        icon: Icons.auto_awesome_rounded,
        title: 'Auto Extract',
        subtitle: 'Add items from a photo',
      ),
    ],
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0x267CA2E4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF7CA2E4), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF636366),
          size: 19,
        ),
      ],
    ),
  );
}

class _AssistPreview extends StatelessWidget {
  const _AssistPreview();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7CA2E4),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Text(
              'Where is my XT30 cable?',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(0x267CA2E4),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF7CA2E4),
                size: 14,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Workshop\nElectronics drawer · 3 available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Ask about your inventory',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 13),
                ),
              ),
              CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF7CA2E4),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TabPreview extends StatelessWidget {
  const _TabPreview({required this.activePage});
  final int activePage;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: const BoxDecoration(
      color: Color(0xFF111113),
      border: Border(top: BorderSide(color: Color(0xFF242426), width: 0.5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Icon(
          Icons.inventory_2_outlined,
          color: activePage < 2
              ? const Color(0xFF7CA2E4)
              : const Color(0xFF636366),
          size: 20,
        ),
        const Icon(
          Icons.qr_code_scanner_rounded,
          color: Color(0xFF636366),
          size: 20,
        ),
        Icon(
          Icons.auto_awesome_rounded,
          color: activePage == 2
              ? const Color(0xFF7CA2E4)
              : const Color(0xFF636366),
          size: 20,
        ),
        const Icon(
          Icons.person_outline_rounded,
          color: Color(0xFF636366),
          size: 20,
        ),
      ],
    ),
  );
}
