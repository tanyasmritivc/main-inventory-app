import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import '../auth/auth_page.dart';
import 'chat_onboarding_draft.dart';
import 'chat_onboarding_world.dart';
import 'sample_scan.dart';

const trialInk = Color(0xFF111112),
    trialBlue = Color(0xFFA9D6F5),
    trialMuted = Color(0xFF6B6C72),
    trialLine = Color(0xFFECEDF0),
    trialOrange = Color(0xFFE8590C);

void trialEvent(String event, [Map<String, Object> values = const {}]) =>
    developer.log('$event $values', name: 'findez.onboarding');

class ChatOnboardingPage extends StatefulWidget {
  const ChatOnboardingPage({
    super.key,
    required this.api,
    this.initialDraft,
    this.onAuthenticatedKeep,
    this.showWorld = true,
  });
  final ApiClient api;
  final ChatOnboardingDraft? initialDraft;
  final VoidCallback? onAuthenticatedKeep;
  final bool showWorld;
  @override
  State<ChatOnboardingPage> createState() => _ChatOnboardingPageState();
}

class _TrialMessage {
  _TrialMessage(this.text, {this.user = false, this.location});
  final String text;
  final bool user;
  final String? location;
}

class _ChatOnboardingPageState extends State<ChatOnboardingPage>
    with WidgetsBindingObserver {
  ChatOnboardingDraft _draft = ChatOnboardingDraft();
  TrialTemplates? _templates;
  final _input = TextEditingController(), _scroll = ScrollController();
  final _messages = <_TrialMessage>[];
  Timer? _keepTimer, _rowsTimer;
  TrialSample? _sample;
  int _generation = 0, _visible = 0, _editing = -1;
  bool _loaded = false, _busy = false, _authOpening = false;
  String? _error, _thinking;
  List<String> _suggestions = [];
  bool get _reduce =>
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;
  bool get _signedIn =>
      Supabase.instance.client.auth.currentUser != null &&
      Supabase.instance.client.auth.currentUser!.isAnonymous == false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    trialEvent('onboarding_started');
    unawaited(_restore());
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  Future<void> _restore() async {
    try {
      final templates = await TrialTemplates.load();
      final sample = await TrialSample.load();
      final draft =
          widget.initialDraft ??
          await ChatOnboardingStore.read() ??
          ChatOnboardingDraft();
      // Old camera trials cannot resume extraction in the offline demo.
      final restored = draft.option == 'snap' ? ChatOnboardingDraft() : draft;
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _sample = sample;
        _error = null;
        _draft = restored;
        _loaded = true;
        _visible = restored.items.length;
        if (restored.isSample && restored.items.isEmpty) {
          _busy = true;
          _thinking = 'Scanning the sample photo...';
        }
      });
      _setSuggestions();
      if (draft.answered &&
          !draft.signupShown &&
          !draft.keep &&
          draft.found >= 0 &&
          draft.found < draft.items.length) {
        final item = draft.items[draft.found];
        _messages.add(_answer(item, draft.question));
        _keepTimer = Timer(
          const Duration(milliseconds: 2200),
          () => unawaited(_showKeep()),
        );
        _scrollDown();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = 'Your trial could not be loaded. Please try again.';
        });
      }
    }
  }

  Future<bool> _persist() async {
    try {
      await ChatOnboardingStore.save(_draft);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save your trial on this device. Please try again.',
        );
      }
      return false;
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scroll.hasClients) return;
    if (_reduce) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    } else {
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  });
  void _setSuggestions() {
    if (_draft.items.isNotEmpty) {
      if (_draft.isSample) {
        _suggestions = [
          'Where is the battery charger?',
          'What model is the charger?',
          'How many screws?',
        ];
        return;
      }
      final items = _draft.items;
      final obvious = items.firstWhere(
        (i) => RegExp(
          r'tape measure|drill|charger|multimeter|hammer|rice|jeans|stapler|flashlight',
          caseSensitive: false,
        ).hasMatch(i.item.name),
        orElse: () => items.first,
      );
      final counted = items.firstWhere(
        (i) => i != obvious && i.item.quantity > 1,
        orElse: () => items.firstWhere(
          (i) => i.item.quantity > 1,
          orElse: () => items.first,
        ),
      );
      _suggestions = [
        'Where is the ${obvious.item.name.toLowerCase()}?',
        'How many ${counted.item.name.toLowerCase()}?',
      ];
    } else {
      _suggestions = switch (_draft.option) {
        'describe' => [
          'Home',
          'Dorm room',
          'Kitchen',
          'Workshop',
          'Lab',
          'Closet',
        ],
        'list' => ['2 phone chargers, 3 notebooks and spare keys'],
        _ => [],
      };
    }
  }

  Future<void> _start(String option) async {
    if (_busy || _templates == null) return;
    final generation = _generation;
    setState(() {
      _draft.option = option;
      _error = null;
      _setSuggestions();
    });
    trialEvent('onboarding_option', {'option': option});
    if (!await _persist() || !mounted || generation != _generation) return;
    if (option == 'sample' && mounted) {
      setState(() {
        _busy = true;
        _thinking = 'Scanning the sample photo...';
      });
    }
  }

  Future<void> _restart() async {
    _generation++;
    _keepTimer?.cancel();
    _rowsTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    final next = ChatOnboardingDraft();
    try {
      await ChatOnboardingStore.save(next);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not restart. Your current trial is still saved.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _draft = next;
      _messages.clear();
      _suggestions.clear();
      _input.clear();
      _visible = 0;
      _editing = -1;
      _thinking = null;
      _busy = false;
      _error = null;
    });
  }

  Future<void> _finishSample() async {
    if (!mounted || !_draft.isSample || !_busy || _sample == null) return;
    _draft.space = _sample!.space;
    _draft.items = _sample!.newItems();
    setState(() {
      _busy = false;
      _thinking = null;
    });
    trialEvent('onboarding_scan_finished');
    await _itemsReady();
  }

  Future<void> _askAnother() async {
    _keepTimer?.cancel();
    setState(() {
      _draft.keep = false;
      _suggestions = _draft.items
          .asMap()
          .entries
          .where((e) => !_draft.asked.contains(e.key))
          .take(3)
          .map((e) => 'Where is the ${e.value.item.name.toLowerCase()}?')
          .toList();
      if (_suggestions.isEmpty) _setSuggestions();
    });
    trialEvent('onboarding_ask_another');
    await _persist();
    _scrollDown();
  }

  Future<void> _submit(String raw) async {
    final text = raw.trim();
    if (_busy || text.isEmpty || _draft.saving || _templates == null) return;
    _input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_draft.items.isNotEmpty) {
      await _ask(text);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _draft.input = text;
    });
    if (_draft.option == 'describe') {
      _templates!.describe(_draft, text);
    } else {
      _templates!.list(_draft, text);
    }
    if (_draft.items.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Try a short list, like: 3 hammers, duct tape.';
      });
      return;
    }
    if (_draft.items.any(
      (row) => row.item.quantity > 100000 || row.item.name.length > 200,
    )) {
      setState(() {
        _draft.items = [];
        _busy = false;
        _error =
            'Use item names under 200 characters and counts up to 100,000.';
      });
      _input.text = text;
      return;
    }
    await _itemsReady();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _itemsReady() async {
    final generation = _generation;
    if (!await _persist() || !mounted || generation != _generation) return;
    trialEvent('onboarding_items_added', {'count': _draft.items.length});
    _setSuggestions();
    _visible = _reduce ? _draft.items.length : 0;
    setState(() {});
    _rowsTimer?.cancel();
    if (!_reduce) {
      _rowsTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
        if (!mounted || _visible >= _draft.items.length) {
          timer.cancel();
          return;
        }
        setState(() => _visible++);
        _scrollDown();
      });
    }
    _scrollDown();
  }

  Future<void> _ask(String question) async {
    final generation = _generation;
    final index = TrialTemplates.matchQuestion(question, _draft.items);
    setState(() {
      _messages.add(_TrialMessage(question, user: true));
      _busy = true;
      _thinking = 'Looking...';
    });
    _scrollDown();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _thinking = null;
      if (index < 0) {
        _messages.add(
          _TrialMessage(
            'That is not on ${_draft.isSample ? 'this workbench' : 'this list'} yet. Try one of these:',
          ),
        );
        _suggestions = _draft.items
            .take(3)
            .map((i) => 'Where is the ${i.item.name.toLowerCase()}?')
            .toList();
      } else {
        final item = _draft.items[index];
        _draft.found = index;
        if (!_draft.asked.contains(index)) _draft.asked.add(index);
        _messages.add(_answer(item, question));
      }
    });
    _scrollDown();
    if (index >= 0 && _draft.answered) await _persist();
    if (index >= 0 && !_draft.answered) {
      _draft.answered = true;
      _draft.question = question;
      trialEvent('onboarding_first_question');
      if (!await _persist() || !mounted) return;
      _keepTimer = Timer(
        const Duration(milliseconds: 2200),
        () => unawaited(_showKeep()),
      );
    }
  }

  _TrialMessage _answer(TrialItem item, String question) {
    final model = RegExp(
      r'model|brand|make|what kind|which',
      caseSensitive: false,
    ).hasMatch(question);
    final counting = RegExp(
      r'how many|count',
      caseSensitive: false,
    ).hasMatch(question);
    final unknown = item.item.scanEvidence?.quantityMissing == true;
    return _TrialMessage(
      model && item.detail != null
          ? 'The ${item.item.name.toLowerCase()} is a **${item.detail!.replaceAll(' · ', ' ')}**, read from its label.'
          : counting
          ? unknown
                ? 'The quantity of ${item.item.name.toLowerCase()} still needs your review.'
                : '**${item.item.quantity}** ${item.item.name.toLowerCase()} in ${_draft.space}.'
          : '${item.item.name} is in **${_draft.space}**, ${item.spot.toLowerCase()}.',
      location: '${_draft.space} · ${item.spot}',
    );
  }

  Future<void> _showKeep() async {
    if (!mounted) return;
    final generation = _generation;
    _draft.keep = true;
    _draft.signupShown = true;
    if (!await _persist() || !mounted || generation != _generation) return;
    trialEvent('onboarding_signup_shown');
    if (_signedIn) {
      widget.onAuthenticatedKeep?.call();
      return;
    }
    setState(() {});
  }

  Future<void> _auth(String? method) async {
    if (_authOpening) return;
    _authOpening = true;
    try {
      if (method != null) {
        _draft.method = method;
        if (!await _persist() || !mounted) return;
      }
      final auth = Supabase.instance.client.auth;
      if ((method == 'email' || method == null) &&
          auth.currentUser?.isAnonymous == true) {
        // Retire an anonymous session left by an older onboarding build.
        await auth.signOut(scope: SignOutScope.local);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _TrialAuthRoute(
            method: method,
            count: method == null || _draft.isSample
                ? null
                : _draft.items.length,
            sample: method != null && _draft.isSample,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open sign in. Please try again.');
      }
    } finally {
      _authOpening = false;
    }
  }

  Future<void> _quantity(int index, int delta) async {
    if (_draft.saving) return;
    final item = _draft.items[index].item;
    setState(() {
      _draft.items[index].quantityEdited = true;
      item.quantity = (item.quantity + delta).clamp(0, 100000);
      item.scanEvidence = item.scanEvidence?.confirmedQuantity();
    });
    await _persist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _keepTimer?.cancel();
    _rowsTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: trialInk,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: trialInk,
        displayColor: trialInk,
      ),
    );
    final themed = Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final chat = _draft.option.isNotEmpty;
              final top = math.min(300.0, constraints.maxHeight * .36);
              final mode = _draft.keep
                  ? 'keep'
                  : _draft.found >= 0
                  ? 'found'
                  : chat
                  ? 'shelf'
                  : 'intro';
              final duration = _reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 600);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1,
                        colors: [Color(0xFFFFEDE2), Colors.white],
                      ),
                    ),
                  ),
                  if (widget.showWorld)
                    ChatOnboardingWorld(
                      mode: mode,
                      filled: _visible,
                      found: _draft.found,
                    ),
                  if (!_loaded)
                    const Center(child: CircularProgressIndicator()),
                  if (_loaded && !chat)
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 480,
                            maxHeight:
                                constraints.maxHeight -
                                MediaQuery.paddingOf(context).top -
                                60,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                            child: _intro(),
                          ),
                        ),
                      ),
                    ),
                  if (_loaded && chat)
                    Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: TrialEntrance(
                        reduce: _reduce,
                        offset: const Offset(0, 1),
                        child: AnimatedSlide(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          offset: _draft.keep
                              ? const Offset(0, 1)
                              : Offset.zero,
                          child: AnimatedOpacity(
                            duration: duration,
                            opacity: _draft.keep ? 0 : 1,
                            child: ColoredBox(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _scroll,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        24,
                                        16,
                                        8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: _conversation(),
                                      ),
                                    ),
                                  ),
                                  SafeArea(top: false, child: _composer()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_draft.keep)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TrialEntrance(
                        reduce: _reduce,
                        offset: const Offset(0, 1),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                constraints.maxHeight -
                                MediaQuery.paddingOf(context).top -
                                64,
                          ),
                          child: _keepSheet(),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: SizedBox(
                          height: 40,
                          child: Stack(
                            children: [
                              if (chat && !_draft.saving)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    tooltip: 'Start over',
                                    onPressed: _restart,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Semantics(
                                  label:
                                      'Onboarding: ${_draft.keep
                                          ? 'keep'
                                          : _draft.answered
                                          ? 'ask'
                                          : _draft.items.isNotEmpty
                                          ? 'list'
                                          : 'add'}',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(4, (index) {
                                      final step = _draft.keep
                                          ? 3
                                          : _draft.answered
                                          ? 2
                                          : _draft.items.isNotEmpty
                                          ? 1
                                          : chat
                                          ? 0
                                          : -1;
                                      return Container(
                                        width: index <= step ? 30 : 22,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: index <= step
                                              ? trialInk
                                              : trialInk.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      );
                                    }),
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
          ),
        ),
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: _reduce),
      child: themed,
    );
  }

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Memory for',
        style: TextStyle(
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.5,
        ),
      ),
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Color(0xFFFFD3B8),
              Color(0xFFFFD3B8),
              Colors.transparent,
            ],
            stops: [0, .64, .64, .92, .92],
          ),
        ),
        child: const Text(
          'physical things.',
          style: TextStyle(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.5,
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 10, bottom: 18),
        child: Text(
          'Try a sample photo. No account needed.',
          style: TextStyle(color: trialMuted, fontSize: 15.5),
        ),
      ),
      SampleScanCard(onTap: () => _start('sample')),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _option('list', 'Type a list', Icons.format_list_bulleted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _option(
              'describe',
              'Describe a space',
              Icons.chat_bubble_outline,
            ),
          ),
        ],
      ),
      Center(
        child: TextButton(
          onPressed: () => _auth(null),
          child: const Text.rich(
            TextSpan(
              text: 'Already have an account? ',
              style: TextStyle(color: trialMuted, fontSize: 14),
              children: [
                TextSpan(
                  text: 'Sign in',
                  style: TextStyle(
                    color: trialInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_error != null) _errorView(),
      if (_error != null && _templates == null)
        TextButton(onPressed: _restore, child: const Text('Try again')),
    ],
  );
  Widget _option(String value, String title, IconData icon) =>
      OutlinedButton.icon(
        onPressed: () => _start(value),
        icon: Icon(icon, size: 14),
        label: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: trialInk,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          side: const BorderSide(color: trialLine),
          shape: const StadiumBorder(),
        ),
      );

  List<Widget> _conversation() => [
    if (!_draft.isSample)
      _message(
        _TrialMessage(
          _draft.option == 'describe'
              ? 'Which space should FindEZ remember first?'
              : 'List a few things. Counts help, but they are optional.',
        ),
      ),
    if (_draft.option == 'describe' && _draft.items.isEmpty && !_busy)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (text) => TrialChip(
                  text: text,
                  highlight: false,
                  onTap: () => _submit(text),
                ),
              )
              .toList(),
        ),
      ),
    if (_draft.input.isNotEmpty)
      _message(_TrialMessage(_draft.input, user: true)),
    if (_draft.isSample && _sample != null)
      Align(
        alignment: Alignment.centerRight,
        child: SampleScanPhoto(
          key: ValueKey(_draft.id),
          sample: _sample!,
          scanning: _draft.items.isEmpty && _busy,
          onFinished: _finishSample,
        ),
      ),
    if (_draft.items.isNotEmpty) ...[
      _message(
        _TrialMessage(
          _draft.isSample
              ? 'Found 7 items. Tap a number to edit.'
              : 'Here is a starter list for the ${_draft.space.toLowerCase()}. Tap a number to fix it.',
        ),
      ),
      _itemCard(),
      if (_visible == _draft.items.length)
        _message(
          _TrialMessage(
            _draft.isSample
                ? 'Now ask where something is.'
                : 'Saved to **${_draft.space}**. Now ask where something is.',
          ),
        ),
    ],
    ..._messages.map(_message),
    if (_thinking != null) TrialThinking(text: _thinking!),
    if (_error != null) _errorView(),
  ];
  Widget _message(_TrialMessage message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: message.user ? const BoxConstraints(maxWidth: 330) : null,
        padding: message.user
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : EdgeInsets.zero,
        decoration: message.user
            ? const BoxDecoration(
                color: trialInk,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: _bold(message.text)),
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: message.user ? Colors.white : trialInk,
              ),
            ),
            if (message.location != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8DA),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  message.location!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC2410C),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  List<TextSpan> _bold(String text) => text
      .split('**')
      .asMap()
      .entries
      .map(
        (e) => TextSpan(
          text: e.value,
          style: e.key.isOdd
              ? const TextStyle(fontWeight: FontWeight.w600)
              : null,
        ),
      )
      .toList();
  Widget _itemCard() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: trialLine),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _draft.space,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$_visible items',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: trialMuted,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _visible; i++) _itemRow(i),
      ],
    ),
  );
  Widget _itemRow(int index) {
    final trial = _draft.items[index],
        item = trial.item,
        edit = _editing == index;
    const colors = [
      trialInk,
      trialBlue,
      Color(0xFFF2F2EF),
      trialInk,
      trialBlue,
      trialInk,
    ];
    return TrialEntrance(
      key: ValueKey('${_draft.id}-$index'),
      reduce: _reduce,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: trialLine)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colors[index % 6],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: trialInk.withValues(alpha: .08)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 14)),
                  if (trial.detail != null)
                    Text(
                      trial.detail!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: trialMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (!edit)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    trial.spot,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: trialMuted),
                  ),
                ),
              ),
            if (edit)
              IconButton(
                tooltip: 'Decrease ${item.name}',
                onPressed: () => _quantity(index, -1),
                icon: const Icon(Icons.remove, size: 18),
              ),
            TextButton(
              onPressed: () => setState(() => _editing = edit ? -1 : index),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: edit ? const Color(0xFFC2410C) : trialInk,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                item.scanEvidence?.quantityMissing == true
                    ? '?'
                    : '${item.quantity}',
                semanticsLabel:
                    '${item.name} quantity ${item.scanEvidence?.quantityMissing == true ? 'unknown' : item.quantity}. Edit quantity',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
            if (edit)
              IconButton(
                tooltip: 'Increase ${item.name}',
                onPressed: () => _quantity(index, 1),
                icon: const Icon(Icons.add, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
    child: Column(
      children: [
        if (_suggestions.isNotEmpty &&
            _thinking == null &&
            !(_draft.option == 'describe' && _draft.items.isEmpty))
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Row(
              children: _suggestions
                  .asMap()
                  .entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TrialChip(
                        text: e.value,
                        highlight: _draft.items.isNotEmpty && e.key == 0,
                        onTap: _busy ? null : () => _submit(e.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: trialLine),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_busy,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    hintStyle: const TextStyle(color: Color(0xFF9A9BA0)),
                    hintText: _draft.items.isNotEmpty
                        ? 'Ask about anything on the list...'
                        : _draft.option == 'describe'
                        ? 'Or describe it, like "my dorm room"'
                        : 'Like: 2 chargers, notebooks, spare keys',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: _busy ? null : () => _submit(_input.text),
                style: IconButton.styleFrom(
                  backgroundColor: trialInk,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _errorView() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        _error!,
        style: const TextStyle(color: Color(0xFFC2410C), fontSize: 14),
      ),
    ),
  );
  Widget _keepSheet() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      boxShadow: [
        BoxShadow(
          color: Color(0x1F1E3C64),
          blurRadius: 50,
          offset: Offset(0, -20),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _draft.isSample
                  ? 'Now try it on real stuff'
                  : 'Keep these ${_draft.items.length} items',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Text(
                _draft.isSample
                    ? 'Make a free account, snap a shelf, and FindEZ remembers every item on every device.'
                    : 'Make an account and FindEZ remembers them, on every device.',
                style: const TextStyle(
                  color: trialMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS)
              _authButton('apple', 'Continue with Apple', Icons.apple, true),
            _authButton(
              'google',
              'Continue with Google',
              Icons.account_circle_outlined,
              false,
            ),
            _authButton(
              'email',
              'Continue with email',
              Icons.mail_outline,
              false,
            ),
            const Text(
              'Free to start. Nothing is shared without permission.',
              textAlign: TextAlign.center,
              style: TextStyle(color: trialMuted, fontSize: 12.5),
            ),
            TextButton(
              onPressed: _askAnother,
              child: const Text(
                'Ask another question',
                style: TextStyle(color: trialInk),
              ),
            ),
            if (_error != null) _errorView(),
          ],
        ),
      ),
    ),
  );
  Widget _authButton(String method, String label, IconData icon, bool dark) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: () => _auth(method),
          style: OutlinedButton.styleFrom(
            backgroundColor: dark ? trialInk : Colors.white,
            foregroundColor: dark ? Colors.white : trialInk,
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: trialLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: method == 'google'
              ? const GoogleAuthLogo(size: 20)
              : Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class _TrialAuthRoute extends StatefulWidget {
  const _TrialAuthRoute({this.method, this.count, this.sample = false});
  final bool sample;
  final String? method;
  final int? count;
  @override
  State<_TrialAuthRoute> createState() => _TrialAuthRouteState();
}

class _TrialAuthRouteState extends State<_TrialAuthRoute> {
  StreamSubscription<AuthState>? _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (mounted &&
          state.session != null &&
          !state.session!.user.isAnonymous) {
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        // Auth can mount another route (for example an invitation sheet) in
        // the same frame. Remove our auth route, never pop that newer route.
        if (route != null && route.isActive) navigator.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    initialMethod: widget.method,
    trialItemCount: widget.count,
    fromOnboarding: widget.count != null || widget.sample,
    sampleTrial: widget.sample,
  );
}

class TrialEntrance extends StatefulWidget {
  const TrialEntrance({
    super.key,
    required this.child,
    required this.reduce,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .12),
  });
  final Offset offset;
  final Widget child;
  final bool reduce;
  final Duration delay;
  @override
  State<TrialEntrance> createState() => _TrialEntranceState();
}

class _TrialEntranceState extends State<TrialEntrance> {
  Timer? _timer;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: _visible || widget.reduce ? Offset.zero : widget.offset,
    duration: widget.reduce ? Duration.zero : const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    child: AnimatedOpacity(
      opacity: _visible || widget.reduce ? 1 : 0,
      duration: widget.reduce
          ? Duration.zero
          : const Duration(milliseconds: 350),
      child: widget.child,
    ),
  );
}

class TrialThinking extends StatefulWidget {
  const TrialThinking({super.key, required this.text});
  final String text;
  @override
  State<TrialThinking> createState() => _TrialThinkingState();
}

class _TrialThinkingState extends State<TrialThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.text,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final t = _motion.value, bob = math.sin(t * math.pi) * -5;
          final text = Text(
            widget.text,
            style: const TextStyle(color: trialMuted, fontSize: 15),
          );
          return Row(
            children: [
              RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(0, bob),
                  child: Transform.rotate(
                    angle: math.sin(t * 2 * math.pi) * .035,
                    alignment: Alignment.bottomCenter,
                    child: SvgPicture.asset(
                      'assets/mascot/pip.svg',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MediaQuery.disableAnimationsOf(context)
                    ? text
                    : ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: const [
                            trialMuted,
                            Color(0xFFC9CBD1),
                            trialMuted,
                          ],
                          stops: [
                            math.max(0, t - .15),
                            t,
                            math.min(1, t + .15),
                          ],
                        ).createShader(bounds),
                        child: text,
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class TrialChip extends StatefulWidget {
  const TrialChip({
    super.key,
    required this.text,
    required this.highlight,
    this.onTap,
  });
  final String text;
  final bool highlight;
  final VoidCallback? onTap;
  @override
  State<TrialChip> createState() => _TrialChipState();
}

class _TrialChipState extends State<TrialChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant TrialChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (!widget.highlight || MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: widget.highlight
            ? [
                BoxShadow(
                  color: trialBlue.withValues(alpha: .6),
                  spreadRadius: 6 * _pulse.value,
                ),
              ]
            : null,
      ),
      child: OutlinedButton(
        onPressed: widget.onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.highlight ? Colors.white : trialInk,
          backgroundColor: widget.highlight ? trialInk : Colors.white,
          side: BorderSide(color: widget.highlight ? trialInk : trialLine),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
        child: Text(
          widget.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ),
  );
}
