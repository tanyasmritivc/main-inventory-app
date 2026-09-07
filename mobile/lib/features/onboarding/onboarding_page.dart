import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onboarding_prefs.dart';

const white = Color(0xFFF2F2F7);
const muted = Color(0xFFAEAEB2);
const surface = Color(0xFF18181A);
const inset = Color(0xFF111113);
const border = Color(0x24FFFFFF);
const lavender = Color(0xFFAA9BDE);
const mint = Color(0xFF8FCDB2);
const rose = Color(0xFFD99BBC);
const sky = Color(0xFF91BEDB);
const coral = Color(0xFFE39A86);

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onFinished,
    this.saveFirstSpace = true,
  });

  final VoidCallback? onFinished;
  final bool saveFirstSpace;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final space = TextEditingController(text: 'Parts Room');
  int step = 0;
  bool creating = false;
  bool spaceMade = false;
  bool itemMade = false;
  bool answered = false;
  bool finishing = false;

  String get spaceName =>
      space.text.trim().isEmpty ? 'Parts Room' : space.text.trim();
  bool get canContinue => switch (step) {
    1 => spaceMade,
    2 => itemMade,
    3 => answered,
    _ => true,
  };
  String get buttonText => switch (step) {
    0 => 'Start the tour',
    1 => spaceMade ? 'Continue' : 'Create a Space above',
    2 => itemMade ? 'Continue' : 'Add the sample item',
    3 => answered ? 'Continue' : 'Ask the question',
    4 => 'Finish tour',
    _ => 'Get started',
  };

  @override
  void dispose() {
    space.dispose();
    super.dispose();
  }

  Future<void> finish(bool keepSpace) async {
    if (finishing) return;
    setState(() => finishing = true);
    await OnboardingPrefs.setPendingFirstSpaceName(
      keepSpace && widget.saveFirstSpace ? spaceName : null,
    );
    await OnboardingPrefs.setPostSignupPending(false);
    await OnboardingPrefs.setCompleted(true);
    if (mounted) widget.onFinished?.call();
  }

  void next() {
    if (!canContinue || finishing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    if (step < 5) {
      setState(() => step++);
    } else {
      finish(spaceMade);
    }
  }

  void back() {
    if (step == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() => step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
          child: Column(
            children: [
              _Top(step: step, back: back, skip: () => finish(false)),
              if (step > 0) ...[
                const SizedBox(height: 8),
                _Progress(step),
                const SizedBox(height: 15),
              ] else
                const SizedBox(height: 4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .985, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (step) {
                    0 => const _Welcome(key: ValueKey('welcome')),
                    1 => _Inventory(
                      key: const ValueKey('inventory'),
                      controller: space,
                      creating: creating,
                      made: spaceMade,
                      open: () => setState(() => creating = true),
                      close: () => setState(() => creating = false),
                      changed: (_) => setState(() {}),
                      create: () {
                        if (space.text.trim().isEmpty) return;
                        FocusManager.instance.primaryFocus?.unfocus();
                        HapticFeedback.mediumImpact();
                        setState(() {
                          spaceMade = true;
                          creating = false;
                        });
                      },
                    ),
                    2 => _Scan(
                      key: const ValueKey('scan'),
                      name: spaceName,
                      made: itemMade,
                      add: () {
                        HapticFeedback.mediumImpact();
                        setState(() => itemMade = true);
                      },
                    ),
                    3 => _Assist(
                      key: const ValueKey('assist'),
                      name: spaceName,
                      answered: answered,
                      ask: () {
                        HapticFeedback.lightImpact();
                        setState(() => answered = true);
                      },
                    ),
                    4 => _Teams(key: const ValueKey('teams'), name: spaceName),
                    _ => _Ready(key: const ValueKey('ready'), name: spaceName),
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canContinue && !finishing ? next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: white,
                    foregroundColor: const Color(0xFF151517),
                    disabledBackgroundColor: const Color(0xFF242426),
                    disabledForegroundColor: const Color(0xFF6C6C70),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: finishing
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF151517),
                          ),
                        )
                      : Text(
                          buttonText,
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
      ),
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.step, required this.back, required this.skip});
  final int step;
  final VoidCallback back;
  final VoidCallback skip;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: step == 0
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FindEZ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: back,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: muted,
                    size: 19,
                  ),
                ),
        ),
        const Spacer(),
        TextButton(
          onPressed: skip,
          child: const Text(
            'Skip',
            style: TextStyle(color: muted, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress(this.step);
  final int step;

  @override
  Widget build(BuildContext context) {
    const colors = [mint, coral, lavender, sky];
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 7),
            decoration: BoxDecoration(
              color: i < step ? colors[i] : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _MapGraphic(),
            const SizedBox(height: 28),
            const Text(
              'Know what you have.\nFind it fast.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 31,
                height: 1.06,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Take a quick tour using a sample inventory.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 28),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Point(Icons.inventory_2_outlined, 'Organize', mint),
                SizedBox(width: 24),
                _Point(Icons.qr_code_scanner_rounded, 'Capture', coral),
                SizedBox(width: 24),
                _Point(Icons.auto_awesome_rounded, 'Find', lavender),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapGraphic extends StatelessWidget {
  const _MapGraphic();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .9, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutBack,
    builder: (_, value, child) => Transform.scale(scale: value, child: child),
    child: SizedBox(
      width: 220,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: border),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
          const Positioned(
            left: 3,
            top: 5,
            child: _Orbit(Icons.hardware_outlined, coral),
          ),
          const Positioned(
            right: 3,
            top: 5,
            child: _Orbit(Icons.groups_outlined, mint),
          ),
          const Positioned(
            left: 22,
            bottom: 0,
            child: _Orbit(Icons.description_outlined, sky),
          ),
          const Positioned(
            right: 22,
            bottom: 0,
            child: _Orbit(Icons.auto_awesome_rounded, lavender),
          ),
        ],
      ),
    ),
  );
}

class _Orbit extends StatelessWidget {
  const _Orbit(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: .42)),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 21),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

enum _Tab { inventory, scan, assist, teams }

class _Frame extends StatelessWidget {
  const _Frame(this.icon, this.color, this.instruction, this.tab, this.child);
  final IconData icon;
  final Color color;
  final String instruction;
  final _Tab tab;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      Expanded(
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Expanded(child: child),
              _Nav(tab),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Nav extends StatelessWidget {
  const _Nav(this.selected);
  final _Tab selected;
  @override
  Widget build(BuildContext context) {
    const entries = [
      (_Tab.inventory, Icons.home_outlined, 'Inventory'),
      (_Tab.scan, Icons.qr_code_scanner_rounded, 'Scan'),
      (_Tab.assist, Icons.chat_bubble_outline_rounded, 'Assist'),
      (_Tab.teams, Icons.groups_outlined, 'Teams'),
    ];
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xF2131315),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: entries
            .map(
              (e) => Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      e.$2,
                      color: selected == e.$1 ? Colors.white : muted,
                      size: 21,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      e.$3,
                      style: TextStyle(
                        color: selected == e.$1 ? Colors.white : muted,
                        fontSize: 10,
                        fontWeight: selected == e.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Inventory extends StatelessWidget {
  const _Inventory({
    super.key,
    required this.controller,
    required this.creating,
    required this.made,
    required this.open,
    required this.close,
    required this.changed,
    required this.create,
  });
  final TextEditingController controller;
  final bool creating;
  final bool made;
  final VoidCallback open;
  final VoidCallback close;
  final ValueChanged<String> changed;
  final VoidCallback create;

  @override
  Widget build(BuildContext context) => _Frame(
    Icons.add_circle_outline_rounded,
    mint,
    made
        ? 'Your Space is ready.'
        : creating
        ? 'Name it, then create it.'
        : 'Tap + to create a Space.',
    _Tab.inventory,
    Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          child: Column(
            children: [
              const _Header('Inventory'),
              const SizedBox(height: 13),
              const _Segment('Spaces', 'Teams', true),
              const SizedBox(height: 12),
              const _Search(),
              const SizedBox(height: 14),
              Expanded(
                child: made
                    ? _SpaceCard(controller.text.trim())
                    : const _Empty(),
              ),
            ],
          ),
        ),
        if (!made && !creating)
          Positioned(right: 16, bottom: 16, child: _Plus(open)),
        if (creating)
          Positioned.fill(
            child: _SpaceSheet(controller, changed, close, create),
          ),
      ],
    ),
  );
}

class _SpaceSheet extends StatelessWidget {
  const _SpaceSheet(this.controller, this.changed, this.close, this.create);
  final TextEditingController controller;
  final ValueChanged<String> changed;
  final VoidCallback close;
  final VoidCallback create;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xB3000000),
    alignment: Alignment.bottomCenter,
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'New Space',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: close,
                icon: const Icon(Icons.close_rounded, color: muted),
              ),
            ],
          ),
          TextField(
            controller: controller,
            onChanged: changed,
            onSubmitted: (_) => create(),
            textCapitalization: TextCapitalization.words,
            maxLength: 48,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              counterText: '',
              prefixIcon: Icon(Icons.inventory_2_outlined, color: mint),
              filled: true,
              fillColor: inset,
              border: _field,
              enabledBorder: _field,
              focusedBorder: _field,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: controller.text.trim().isEmpty ? null : create,
              style: FilledButton.styleFrom(
                backgroundColor: white,
                foregroundColor: const Color(0xFF151517),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Create Space',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const _field = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(15)),
  borderSide: BorderSide(color: border),
);

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, color: Color(0xFF555559), size: 34),
        SizedBox(height: 10),
        Text(
          'Your inventory starts here',
          style: TextStyle(color: muted, fontSize: 13),
        ),
      ],
    ),
  );
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: mint, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '0 items',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: mint, size: 20),
        ],
      ),
    ),
  );
}

class _Plus extends StatelessWidget {
  const _Plus(this.tap);
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xE62C2C2E),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x45FFFFFF)),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    ),
  );
}

class _Scan extends StatelessWidget {
  const _Scan({
    super.key,
    required this.name,
    required this.made,
    required this.add,
  });
  final String name;
  final bool made;
  final VoidCallback add;
  @override
  Widget build(BuildContext context) => _Frame(
    Icons.add_photo_alternate_outlined,
    coral,
    made
        ? 'FindEZ extracted the item details.'
        : 'Tap the sample photo to add an item.',
    _Tab.scan,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        children: [
          const _Header('Scan'),
          const SizedBox(height: 13),
          const _Segment('Scan Barcode', 'Auto Extract', false),
          const SizedBox(height: 15),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: made
                  ? _Item(name, key: const ValueKey('item'))
                  : _Photo(add, key: const ValueKey('photo')),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo(this.tap, {super.key});
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: coral.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.hardware_outlined, color: coral, size: 37),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sample: M4 bolts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap to extract',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: mint, size: 21),
            SizedBox(width: 8),
            Text(
              'Ready to save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Data('NAME', 'M4 bolts'),
        const SizedBox(height: 7),
        const Row(
          children: [
            Expanded(child: _Data('CATEGORY', 'Hardware')),
            SizedBox(width: 10),
            Expanded(child: _Data('QUANTITY', '24')),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: mint, size: 17),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Saving to $name',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Data extends StatelessWidget {
  const _Data(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: inset,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: muted, fontSize: 9, letterSpacing: .7),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    ),
  );
}

class _Assist extends StatelessWidget {
  const _Assist({
    super.key,
    required this.name,
    required this.answered,
    required this.ask,
  });
  final String name;
  final bool answered;
  final VoidCallback ask;
  @override
  Widget build(BuildContext context) => _Frame(
    Icons.auto_awesome_rounded,
    lavender,
    answered
        ? 'Assist answers from your inventory.'
        : 'Send the sample inventory question.',
    _Tab.assist,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        children: [
          const _Header('Assist'),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: answered
                  ? Column(
                      key: const ValueKey('conversation'),
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: _Bubble('Where are the M4 bolts?', true),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _Bubble('24 M4 bolts are in $name.', false),
                        ),
                        const SizedBox(height: 12),
                        _Result(name),
                      ],
                    )
                  : const Center(
                      key: ValueKey('empty-assist'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: lavender,
                            size: 34,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Ask about your inventory',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: ask,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Where are the M4 bolts?',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Color(0xFF151517),
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, this.mine);
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 245),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: mine ? const Color(0xFF2C2C2E) : inset,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: border),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.25),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        const Icon(Icons.hardware_outlined, color: coral, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'M4 bolts · 24',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _Teams extends StatelessWidget {
  const _Teams({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => _Frame(
    Icons.groups_outlined,
    sky,
    'Everything the team needs stays connected.',
    _Tab.teams,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Build Team'),
          const SizedBox(height: 14),
          Row(
            children: [
              const _Avatars(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$name · 3 members',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _TeamTile(
                          Icons.inventory_2_outlined,
                          'Spaces',
                          'Shared inventory',
                          mint,
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: _TeamTile(
                          Icons.task_alt_rounded,
                          'Board',
                          'Tasks and requests',
                          coral,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 7),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _TeamTile(
                          Icons.groups_outlined,
                          'People',
                          'Members and roles',
                          lavender,
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: _TeamTile(
                          Icons.description_outlined,
                          'Documents',
                          'Files and photos',
                          sky,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 7),
                _Activity(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TeamTile extends StatelessWidget {
  const _TeamTile(this.icon, this.label, this.detail, this.color);
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const Spacer(),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          detail,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _Activity extends StatelessWidget {
  const _Activity();
  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: const Row(
      children: [
        Icon(Icons.history_rounded, color: rose, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Maya updated M4 bolts',
            style: TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        Text('now', style: TextStyle(color: muted, fontSize: 10)),
      ],
    ),
  );
}

class _Avatars extends StatelessWidget {
  const _Avatars();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 73,
    height: 34,
    child: Stack(
      children: const [
        _Avatar(0, 'T', lavender),
        _Avatar(20, 'M', mint),
        _Avatar(40, 'V', coral),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.left, this.label, this.color);
  final double left;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    child: Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B0B0D), width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF111113),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Ready extends StatelessWidget {
  const _Ready({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .75, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (_, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: mint.withValues(alpha: .13),
                  shape: BoxShape.circle,
                  border: Border.all(color: mint.withValues(alpha: .45)),
                ),
                child: const Icon(Icons.check_rounded, color: mint, size: 39),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'You know the flow.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Your real inventory starts next.',
              style: TextStyle(color: muted, fontSize: 15),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _ReadyRow(
                    Icons.inventory_2_outlined,
                    mint,
                    name,
                    'Created after sign-in',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Divider(height: 1, color: border),
                  ),
                  const _ReadyRow(
                    Icons.hardware_outlined,
                    coral,
                    'M4 bolts',
                    'Tour sample only',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Divider(height: 1, color: border),
                  ),
                  const _ReadyRow(
                    Icons.groups_outlined,
                    lavender,
                    'Team-ready',
                    'Invite people when you are ready',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow(this.icon, this.color, this.title, this.detail);
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const Icon(Icons.notifications_none_rounded, color: muted, size: 20),
    ],
  );
}

class _Segment extends StatelessWidget {
  const _Segment(this.left, this.right, this.leftActive);
  final String left;
  final String right;
  final bool leftActive;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF262629),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        _SegmentLabel(left, leftActive),
        _SegmentLabel(right, !leftActive),
      ],
    ),
  );
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.label, this.active);
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4A4A4D) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? Colors.white : muted,
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _Search extends StatelessWidget {
  const _Search();
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: border),
    ),
    child: const Row(
      children: [
        Icon(Icons.search_rounded, color: muted, size: 19),
        SizedBox(width: 8),
        Text(
          'Search inventory',
          style: TextStyle(color: Color(0xFF737377), fontSize: 12),
        ),
      ],
    ),
  );
}
