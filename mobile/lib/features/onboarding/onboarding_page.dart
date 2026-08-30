import 'dart:ui';

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
    ('STEP 1 OF 3', 'Give everything\na place.', 'Create a Space for a room, workshop, team, or project.', Icons.folder_rounded, 'Workshop', '42 items · Everything has a home'),
    ('STEP 2 OF 3', 'Add it in\nseconds.', 'Type it, scan a barcode, or use Auto Extract from a photo.', Icons.document_scanner_rounded, 'Capture your way', 'Type · Scan · Auto Extract'),
    ('STEP 3 OF 3', 'Find anything.\nInstantly.', 'Search normally or ask Assist exactly where something is.', Icons.auto_awesome_rounded, '“Where is my XT30 cable?”', 'Workshop → Electronics drawer'),
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
    if (_page == _steps.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
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
              padding: const EdgeInsets.fromLTRB(24, 10, 14, 0),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Color(0xFF0A84FF), size: 20),
                  const SizedBox(width: 8),
                  const Text('FindEZ', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                  const Spacer(),
                  TextButton(onPressed: _finishing ? null : _finish, child: const Text('Skip', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15))),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _Step(data: _steps[index], index: index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: index == _page ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: index == _page ? const Color(0xFF0A84FF) : const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(99)),
                    )),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0A84FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _finishing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_page == _steps.length - 1 ? 'Start organizing' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

class _Step extends StatelessWidget {
  const _Step({required this.data, required this.index});
  final (String, String, String, IconData, String, String) data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.$1, style: const TextStyle(color: Color(0xFF0A84FF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Text(data.$2, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -1.2)),
          const SizedBox(height: 14),
          Text(data.$3, style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 17, height: 1.4, letterSpacing: -0.15)),
          const SizedBox(height: 28),
          Expanded(child: _Visual(data: data, index: index)),
        ],
      ),
    );
  }
}

class _Visual extends StatelessWidget {
  const _Visual({required this.data, required this.index});
  final (String, String, String, IconData, String, String) data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 290),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x383A8DFF), Color(0x18FFFFFF)]),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x38FFFFFF), width: 0.8),
              ),
              child: index == 2 ? _assist() : _standard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _standard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: const Color(0xFF0A84FF).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(17)),
        child: Icon(data.$4, color: const Color(0xFF0A84FF), size: 31),
      ),
      const Spacer(),
      Text(data.$5, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
      const SizedBox(height: 7),
      Text(data.$6, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14)),
      const SizedBox(height: 18),
      Row(children: index == 0
          ? const [_Tag(Icons.handyman_rounded, 'Tools'), SizedBox(width: 8), _Tag(Icons.memory_rounded, 'Parts')]
          : const [_Tag(Icons.keyboard_rounded, 'Type'), SizedBox(width: 8), _Tag(Icons.qr_code_scanner_rounded, 'Scan'), SizedBox(width: 8), _Tag(Icons.auto_awesome_rounded, 'Extract')]),
    ],
  );

  Widget _assist() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFF0A84FF), borderRadius: BorderRadius.circular(18)),
          child: Text(data.$5, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        const CircleAvatar(radius: 15, backgroundColor: Color(0x260A84FF), child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF0A84FF), size: 15)),
        const SizedBox(width: 11),
        Expanded(child: Text('${data.$6}\n3 cables available', style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.45))),
      ]),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFFAEAEB2), size: 13),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}
