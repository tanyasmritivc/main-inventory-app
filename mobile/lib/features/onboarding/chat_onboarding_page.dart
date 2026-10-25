import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import '../auth/auth_page.dart';
import 'chat_onboarding_camera.dart';
import 'chat_onboarding_draft.dart';
import 'chat_onboarding_world.dart';

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
    this.photoPicker,
    this.photoExtractor,
    this.showWorld = true,
  });
  final ApiClient api;
  final ChatOnboardingDraft? initialDraft;
  final VoidCallback? onAuthenticatedKeep;
  final Future<XFile?> Function()? photoPicker;
  final Future<MultiExtractResult> Function(XFile photo, CancelToken token)?
  photoExtractor;
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

class _ChatOnboardingPageState extends State<ChatOnboardingPage> {
  ChatOnboardingDraft _draft = ChatOnboardingDraft();
  TrialTemplates? _templates;
  final _input = TextEditingController(), _scroll = ScrollController();
  final _messages = <_TrialMessage>[];
  Timer? _keepTimer, _rowsTimer;
  CancelToken? _cancel;
  int _generation = 0, _visible = 0, _editing = -1;
  bool _loaded = false, _busy = false, _authOpening = false;
  String? _error, _thinking;
  List<String> _suggestions = [];
  bool get _reduce => MediaQuery.disableAnimationsOf(context);
  bool get _signedIn =>
      Supabase.instance.client.auth.currentUser != null &&
      Supabase.instance.client.auth.currentUser!.isAnonymous == false;

  @override
  void initState() {
    super.initState();
    trialEvent('onboarding_started');
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final templates = await TrialTemplates.load();
      final draft =
          widget.initialDraft ??
          await ChatOnboardingStore.read() ??
          ChatOnboardingDraft();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _error = null;
        _draft = draft;
        _loaded = true;
        _visible = draft.items.length;
      });
      _setSuggestions();
      if (draft.answered &&
          !draft.keep &&
          draft.found >= 0 &&
          draft.found < draft.items.length) {
        final item = draft.items[draft.found];
        _messages.add(_answer(item, draft.question));
        _keepTimer = Timer(
          const Duration(milliseconds: 1900),
          () => unawaited(_showKeep()),
        );
        _scrollDown();
      }
      if (draft.photoPending && _signedIn && draft.photoPath != null) {
        await _extract(XFile(draft.photoPath!));
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
          'Garage',
          'Workshop',
          'Kitchen',
          'Lab',
          'Closet',
          'Craft room',
        ],
        'list' => ['20 M3 screws, 4 batteries, a drill and 2 multimeters'],
        _ => [],
      };
    }
  }

  Future<void> _start(String option) async {
    if (_busy || _templates == null) return;
    setState(() {
      _draft.option = option;
      _error = null;
      _setSuggestions();
    });
    trialEvent('onboarding_option', {'option': option});
    if (!await _persist() || !mounted) return;
    if (option == 'snap') await _snap();
  }

  Future<void> _restart() async {
    _generation++;
    _cancel?.cancel();
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

  Future<void> _snap() async {
    if (_busy) return;
    final generation = ++_generation;
    final photo =
        await (widget.photoPicker?.call() ??
            Navigator.of(context).push<XFile>(
              MaterialPageRoute(builder: (_) => const ChatOnboardingCamera()),
            ));
    if (!mounted || generation != _generation || photo == null) return;
    try {
      final directory = await getApplicationSupportDirectory();
      final path =
          '${directory.path}/onboarding-${_draft.id}.${photo.name.split('.').last}';
      await photo.saveTo(path);
      if (!mounted || generation != _generation) return;
      setState(() {
        _draft.photoPath = path;
        _draft.photoPending = true;
      });
      if (await _persist() && mounted) await _extract(XFile(path));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not keep the photo. Please try again.');
      }
    }
  }

  Future<void> _extract(XFile photo) async {
    final generation = ++_generation;
    final token = _cancel = CancelToken();
    setState(() {
      _busy = true;
      _thinking = 'Reading the photo...';
      _error = null;
      _draft.keep = false;
    });
    _scrollDown();
    try {
      if (widget.photoExtractor == null &&
          Supabase.instance.client.auth.currentSession == null) {
        try {
          await Supabase.instance.client.auth.signInAnonymously();
        } on AuthException catch (error) {
          if ([
                'anonymous_provider_disabled',
                'signup_disabled',
              ].contains(error.code) ||
              error.statusCode == '403' ||
              error.statusCode == '401') {
            throw const _TrialAuthRequired();
          }
          rethrow;
        }
      }
      if (!mounted || generation != _generation) return;
      final result =
          await (widget.photoExtractor?.call(photo, token) ??
              widget.api.extractInventoryFromImage(
                bytes: await photo.readAsBytes(),
                filename: photo.name,
                cancelToken: token,
              ));
      if (!mounted || generation != _generation) return;
      if (result.items.isEmpty) {
        setState(
          () => _error =
              'No items were found. Try a closer photo or type a list.',
        );
        return;
      }
      final alreadyAnswered = _draft.answered;
      final previous = _draft.items;
      _draft.space = 'Workbench';
      _draft.items = result.items
          .map((i) => TrialItem(i, 'Workbench'))
          .toList();
      // When identity linking falls back to ordinary sign-in, obtain fresh
      // server evidence while retaining explicit edits for unambiguous matches.
      for (final row in _draft.items) {
        final matches = previous
            .where(
              (old) =>
                  old.quantityEdited &&
                  old.item.name.toLowerCase() == row.item.name.toLowerCase(),
            )
            .toList();
        if (matches.length == 1 &&
            _draft.items
                    .where(
                      (other) =>
                          other.item.name.toLowerCase() ==
                          row.item.name.toLowerCase(),
                    )
                    .length ==
                1) {
          row.item.quantity = matches.single.item.quantity;
          row.item.scanEvidence = row.item.scanEvidence?.confirmedQuantity();
          row.quantityEdited = true;
        }
      }
      _draft.extractedBy = Supabase.instance.client.auth.currentUser?.id;
      _draft.photoPending = false;
      _draft.answered = false;
      _draft.found = -1;
      await _itemsReady();
      if (alreadyAnswered && mounted && generation == _generation) {
        _draft.answered = true;
        await _showKeep();
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (error is _TrialAuthRequired ||
          error is SessionExpiredException ||
          (error is DioException &&
              [401, 403].contains(error.response?.statusCode))) {
        _messages.add(_TrialMessage('Make a free account to read this photo.'));
        _draft.photoPending = true;
        await _showKeep();
      } else if (error is! DioException || !CancelToken.isCancel(error)) {
        setState(
          () => _error =
              'Could not read the photo. Check your connection and try again, or type a list.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _thinking = null;
        });
      }
    }
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
            'That is not in ${_draft.space} yet. Try one of these:',
          ),
        );
        _suggestions = _draft.items
            .take(3)
            .map((i) => 'Where is the ${i.item.name.toLowerCase()}?')
            .toList();
      } else {
        final item = _draft.items[index];
        _draft.found = index;
        _messages.add(_answer(item, question));
      }
    });
    _scrollDown();
    if (index >= 0 && !_draft.answered) {
      _draft.answered = true;
      _draft.question = question;
      trialEvent('onboarding_first_question');
      if (!await _persist() || !mounted) return;
      _keepTimer = Timer(
        const Duration(milliseconds: 1900),
        () => unawaited(_showKeep()),
      );
    }
  }

  _TrialMessage _answer(TrialItem item, String question) {
    final counting = RegExp(
      r'how many|count',
      caseSensitive: false,
    ).hasMatch(question);
    final unknown = item.item.scanEvidence?.quantityMissing == true;
    return _TrialMessage(
      counting
          ? unknown
                ? 'The quantity of ${item.item.name.toLowerCase()} still needs your review.'
                : '**${item.item.quantity}** ${item.item.name.toLowerCase()} in ${_draft.space}.'
          : '${item.item.name} is in **${_draft.space}**, ${item.spot.toLowerCase()}.',
      location: counting ? null : '${_draft.space} · ${item.spot}',
    );
  }

  Future<void> _showKeep() async {
    if (!mounted) return;
    final generation = _generation;
    _draft.keep = true;
    if (!await _persist() || !mounted || generation != _generation) return;
    trialEvent('onboarding_signup_shown');
    if (_signedIn && !_draft.photoPending) {
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
        // Email retains the existing verified email flow. The photo is kept
        // locally and extracted again under the permanent account if needed.
        await auth.signOut(scope: SignOutScope.local);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _TrialAuthRoute(
            method: method,
            count: method == null ? null : _draft.items.length,
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
    _generation++;
    _cancel?.cancel();
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
      fontFamily: 'PlusJakartaSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: trialInk,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'PlusJakartaSans',
        bodyColor: trialInk,
        displayColor: trialInk,
      ),
    );
    return Theme(
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF0F7FD), Colors.white],
                        stops: [0, .6],
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
              trialBlue,
              trialBlue,
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
          'Try it before signing up. Pick one.',
          style: TextStyle(color: trialMuted, fontSize: 15.5),
        ),
      ),
      _option(
        'snap',
        'Snap a shelf.',
        'FindEZ lists what it sees',
        Icons.camera_alt_outlined,
        0,
      ),
      _option(
        'list',
        'Type a list.',
        'Like: 20 M3 screws, a drill',
        Icons.format_list_bulleted,
        1,
      ),
      _option(
        'describe',
        'Describe a space.',
        'Like: my garage',
        Icons.chat_bubble_outline,
        2,
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
  Widget _option(
    String value,
    String title,
    String subtitle,
    IconData icon,
    int index,
  ) => TrialEntrance(
    reduce: _reduce,
    delay: Duration(milliseconds: 60 * index),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: trialLine),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1E3C64),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _start(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: value == 'snap'
                          ? trialOrange
                          : const Color(0xFFEEF6FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: trialInk, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: trialMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFB4B6BC),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  List<Widget> _conversation() => [
    _message(
      _TrialMessage(switch (_draft.option) {
        'describe' => 'Which space should FindEZ remember first?',
        'list' => 'List a few things. Counts help, but they are optional.',
        _ => 'Point the camera at a shelf, bin or bench.',
      }),
    ),
    if (_draft.input.isNotEmpty)
      _message(_TrialMessage(_draft.input, user: true)),
    if (_draft.photoPath != null)
      Align(
        alignment: Alignment.centerRight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(_draft.photoPath!),
            width: 230,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('Photo unavailable. Take another photo.'),
          ),
        ),
      ),
    if (_draft.items.isNotEmpty) ...[
      _message(
        _TrialMessage(
          _draft.option == 'snap'
              ? 'Found ${_draft.items.length} things on the bench. Tap a number to fix it.'
              : 'Here is a starter list for the ${_draft.space.toLowerCase()}. Tap a number to fix it.',
        ),
      ),
      _itemCard(),
      if (_visible == _draft.items.length)
        _message(
          _TrialMessage(
            'Saved to **${_draft.space}**. Now ask where something is.',
          ),
        ),
    ],
    ..._messages.map(_message),
    if (_thinking != null) TrialThinking(text: _thinking!),
    if (_error != null) _errorView(),
    if (_draft.option == 'snap' && !_busy && _draft.items.isEmpty)
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _draft.photoPath == null
                ? _snap
                : () => _extract(XFile(_draft.photoPath!)),
            child: Text(
              _draft.photoPath == null ? 'Take a photo' : 'Try again',
            ),
          ),
          TextButton(
            onPressed: () => _start('list'),
            child: const Text('Type a list'),
          ),
        ],
      ),
    if (_busy && _draft.option == 'snap')
      TextButton(
        onPressed: () {
          _generation++;
          _cancel?.cancel();
          setState(() {
            _busy = false;
            _thinking = null;
          });
        },
        child: const Text('Stop'),
      ),
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
                  fontFamily: 'GeistMono',
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
                  if (!edit)
                    Text(
                      trial.spot,
                      style: const TextStyle(fontSize: 12, color: trialMuted),
                    ),
                ],
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
                style: const TextStyle(fontFamily: 'GeistMono', fontSize: 13),
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
        if (_suggestions.isNotEmpty && _thinking == null)
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
                        : 'Like: 3 hammers, duct tape, 12 AA batteries',
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
              _draft.photoPending
                  ? 'Make a free account to read this photo.'
                  : 'Keep these ${_draft.items.length} items',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 20),
              child: Text(
                'Make an account and FindEZ remembers them, on every device.',
                style: TextStyle(color: trialMuted, fontSize: 15, height: 1.4),
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
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class _TrialAuthRequired implements Exception {
  const _TrialAuthRequired();
}

class _TrialAuthRoute extends StatefulWidget {
  const _TrialAuthRoute({this.method, this.count});
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
    fromOnboarding: widget.count != null,
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
