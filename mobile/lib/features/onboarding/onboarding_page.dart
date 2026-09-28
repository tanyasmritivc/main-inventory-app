import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../auth/auth_page.dart';
import '../import/import_sheet_page.dart';
import 'onboarding_prefs.dart';

enum _Step {
  welcome,
  camera,
  running,
  review,
  memory,
  ask,
  who,
  import,
  invite,
  policy,
  done,
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.api,
    this.onFinished,
    this.saveFirstSpace = true,
  });

  final ApiClient api;
  final VoidCallback? onFinished;
  final bool saveFirstSpace;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with WidgetsBindingObserver {
  final _place = TextEditingController();
  final _inviteEmail = TextEditingController();
  _Step _step = _Step.welcome;
  CameraController? _camera;
  bool _cameraLoading = false;
  bool _working = false;
  bool _restoring = true;
  bool _awaitingAccount = false;
  String? _cameraError;
  String? _error;
  String? _capturePath;
  String? _persona;
  List<ExtractedInventoryItem> _items = [];
  final Set<ExtractedInventoryItem> _confirmedIdentities = {};
  List<InventoryItem> _saved = [];
  List<Map<String, dynamic>> _relationships = [];
  bool _relationshipsLoading = false;
  String? _memoryError;
  List<Map<String, dynamic>> _teams = [];
  bool _teamsLoading = false;
  String? _selectedTeamId;
  int _savedCount = 0;

  bool get _signedIn => Supabase.instance.client.auth.currentSession != null;

  List<_Step> get _path => switch (_persona) {
    'team' => const [
      _Step.welcome,
      _Step.camera,
      _Step.running,
      _Step.review,
      _Step.memory,
      _Step.ask,
      _Step.who,
      _Step.invite,
      _Step.done,
    ],
    'organization' => const [
      _Step.welcome,
      _Step.camera,
      _Step.running,
      _Step.review,
      _Step.memory,
      _Step.ask,
      _Step.who,
      _Step.import,
      _Step.invite,
      _Step.policy,
      _Step.done,
    ],
    _ => const [
      _Step.welcome,
      _Step.camera,
      _Step.running,
      _Step.review,
      _Step.memory,
      _Step.ask,
      _Step.who,
      _Step.done,
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreCapture());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_closeCamera());
    _place.dispose();
    _inviteEmail.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == _Step.camera &&
        !_awaitingAccount) {
      unawaited(_openCamera());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_closeCamera());
    }
  }

  Future<void> _restoreCapture() async {
    try {
      if (!widget.saveFirstSpace) return;
      final path = await OnboardingPrefs.getPendingCapturePath();
      if (!mounted || path == null) return;
      if (!await File(path).exists()) {
        await OnboardingPrefs.setPendingCapturePath(null);
        return;
      }
      _capturePath = path;
      if (_signedIn) {
        setState(() => _step = _Step.running);
        unawaited(_extract());
      } else {
        setState(() {
          _step = _Step.camera;
          _awaitingAccount = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openCamera() async {
    if (_cameraLoading ||
        _camera != null ||
        _step != _Step.camera ||
        _awaitingAccount) {
      return;
    }
    _cameraLoading = true;
    setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera');
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      final camera = CameraController(
        back.isEmpty ? cameras.first : back.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted || _step != _Step.camera || _awaitingAccount) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => _cameraError = error.code.toLowerCase().contains('denied')
              ? 'Camera access is off. Allow it in Settings or choose a photo.'
              : 'The camera could not start. Try again or choose a photo.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError =
              'The camera could not start. Try again or choose a photo.',
        );
      }
    } finally {
      _cameraLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  void _cameraStep() {
    setState(() {
      _step = _Step.camera;
      _error = null;
      _awaitingAccount = false;
    });
    unawaited(_openCamera());
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || _working) return;
    setState(() => _working = true);
    try {
      final photo = await camera.takePicture();
      if (mounted) setState(() => _working = false);
      await _keepPhoto(photo);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The photo was not captured. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (_working) return;
    try {
      final file = await picker.ImagePicker().pickImage(
        source: picker.ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file != null) await _keepPhoto(file);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The photo could not be opened. Please try again.',
        );
      }
    }
  }

  Future<void> _keepPhoto(picker.XFile photo) async {
    final directory = await getApplicationSupportDirectory();
    final path =
        '${directory.path}/${widget.saveFirstSpace ? 'onboarding-capture.jpg' : 'onboarding-preview.jpg'}';
    await File(photo.path).copy(path);
    if (widget.saveFirstSpace) {
      await OnboardingPrefs.setPendingCapturePath(path);
    }
    await _closeCamera();
    if (!mounted) return;
    _capturePath = path;
    _items = [];
    _confirmedIdentities.clear();
    _saved = [];
    _relationships = [];
    _memoryError = null;
    if (!_signedIn) {
      setState(() => _awaitingAccount = true);
      return;
    }
    setState(() => _step = _Step.running);
    await _extract();
  }

  Future<void> _extract() async {
    final path = _capturePath;
    if (path == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
      _step = _Step.running;
    });
    try {
      final bytes = await File(path).readAsBytes();
      final result = await widget.api.extractInventoryFromImage(
        bytes: bytes,
        filename: 'capture.jpg',
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        if (_items.isEmpty) {
          _error =
              'Nothing could be identified in this photo. Try another angle or more light.';
        } else {
          _step = _Step.review;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _fix(ExtractedInventoryItem item) async {
    final controller = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What is this?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Object name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Use name'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        item.name = name;
        _confirmedIdentities.add(item);
      });
    }
  }

  bool _needsIdentity(ExtractedInventoryItem item) {
    if (_confirmedIdentities.contains(item)) return false;
    final name = item.name.trim().toLowerCase();
    return name.isEmpty ||
        name == 'unknown' ||
        name == 'unknown item' ||
        name == 'unidentified' ||
        (item.scanEvidence?.needsReview ?? false);
  }

  Future<void> _remember() async {
    if (!widget.saveFirstSpace) {
      await _finish();
      return;
    }
    final place = _place.text.trim();
    if (place.isEmpty || _working) return;
    final unnamed = _items.where(_needsIdentity).toList();
    if (unnamed.isNotEmpty) {
      setState(
        () => _error =
            'Review each object that still needs an identity before saving it.',
      );
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final places = await widget.api.listSpaces();
      final exists = places.any(
        (row) =>
            (row['name'] ?? '').toString().trim().toLowerCase() ==
            place.toLowerCase(),
      );
      if (!exists) await widget.api.createSpace(name: place);
      for (final item in _items) {
        item.location = place;
      }
      final result = await widget.api.bulkCreateInventory(items: _items);
      if (!mounted) return;
      _saved = result.inserted;
      _savedCount = _saved.length;
      if (_saved.isEmpty) {
        setState(
          () => _error = result.failures.isEmpty
              ? 'No objects were saved. Check the names and try again.'
              : 'No objects were saved. Check the objects and try again.',
        );
        return;
      }
      setState(() {
        _step = _Step.memory;
        if (_saved.length != _items.length) {
          _error =
              '${_saved.length} of ${_items.length} objects were saved. The rest need another capture.';
        }
      });
      unawaited(_loadMemoryRelationships(_saved.first.itemId));
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _loadMemoryRelationships(String itemId) async {
    setState(() {
      _relationshipsLoading = true;
      _memoryError = null;
    });
    try {
      final relationships = await widget.api.itemRelationships(itemId);
      if (mounted) setState(() => _relationships = relationships);
    } catch (error) {
      if (mounted) setState(() => _memoryError = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _relationshipsLoading = false);
    }
  }

  Future<void> _selectPersona(String persona) async {
    await OnboardingPrefs.setPersona(persona);
    if (!mounted) return;
    setState(() {
      _persona = persona;
      _step = switch (persona) {
        'team' => _Step.invite,
        'organization' => _Step.import,
        _ => _Step.done,
      };
    });
    if (persona != 'solo') unawaited(_loadTeams());
  }

  Future<void> _loadTeams() async {
    setState(() {
      _teamsLoading = true;
      _error = null;
    });
    try {
      final teams = await widget.api.listTeams();
      if (mounted) {
        setState(() {
          _teams = teams;
          _selectedTeamId = teams.length == 1
              ? teams.first['team_id']?.toString()
              : null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _teamsLoading = false);
    }
  }

  Future<void> _sendInvite() async {
    final email = _inviteEmail.text.trim();
    final teamId = _selectedTeamId ?? '';
    if (email.isEmpty || teamId.isEmpty || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.api.emailTeamInvite(teamId, email);
      if (mounted) {
        setState(() {
          _inviteEmail.clear();
          _step = _persona == 'organization' ? _Step.policy : _Step.done;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _finish() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      if (widget.saveFirstSpace) {
        await OnboardingPrefs.setPendingCapturePath(null);
        await OnboardingPrefs.setPostSignupPending(false);
        await OnboardingPrefs.setCompleted(true);
        OnboardingPrefs.justSignedUp = false;
      }
      final path = _capturePath;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (error) {
          debugPrint('Could not remove temporary onboarding photo: $error');
        }
      }
      if (mounted) widget.onFinished?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _error = describeError(error).$1);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _next() => setState(() {
    _error = null;
    _step = switch (_step) {
      _Step.memory => _Step.ask,
      _Step.ask => _Step.who,
      _Step.import => _Step.invite,
      _Step.invite => _persona == 'organization' ? _Step.policy : _Step.done,
      _Step.policy => _Step.done,
      _ => _step,
    };
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (_restoring) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Text(
            'Getting your photo ready',
            style: TextStyle(color: t.text2, fontSize: 15),
          ),
        ),
      );
    }
    if (_awaitingAccount) {
      return AuthPage(
        onAuthChanged: () {
          if (mounted) setState(() {});
        },
      );
    }
    final index = _path.indexOf(_step);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    'FindEZ',
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${index < 0 ? 1 : index + 1} / ${_path.length}',
                    style: TextStyle(color: t.text3, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(
                value: index < 0 ? 0 : (index + 1) / _path.length,
                color: t.accent,
                backgroundColor: t.s3,
                minHeight: 2,
              ),
            ),
            Expanded(
              child: _step == _Step.camera
                  ? _cameraBody(t)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                      child: _body(t),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: t.danger, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppTokens t) => switch (_step) {
    _Step.welcome => _welcome(t),
    _Step.running => _running(t),
    _Step.review => _review(t),
    _Step.memory => _memory(t),
    _Step.ask => _ask(t),
    _Step.who => _who(t),
    _Step.import => _import(t),
    _Step.invite => _invite(t),
    _Step.policy => _policy(t),
    _Step.done => _done(t),
    _Step.camera => const SizedBox.shrink(),
  };

  Widget _title(AppTokens t, String title, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: t.ink,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: t.text2, fontSize: 15)),
      ],
      const SizedBox(height: 24),
    ],
  );

  Widget _card(AppTokens t, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(AppTokens.radius),
    ),
    child: child,
  );

  Widget _action(String label, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: AppTokens.buttonHeight,
    child: FilledButton(onPressed: onPressed, child: Text(label)),
  );

  Widget _welcome(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: 160, child: CustomPaint(painter: _MemoryPainter(t))),
      const SizedBox(height: 30),
      _title(t, 'FindEZ gives the physical world a memory.'),
      _action('Take a photo', _cameraStep),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => setState(() => _awaitingAccount = true),
        child: const Text('I have an invitation'),
      ),
      TextButton(
        onPressed: () => setState(() => _awaitingAccount = true),
        child: const Text('Sign in'),
      ),
    ],
  );

  Widget _cameraBody(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: _title(
          t,
          'Point it at anything you own.',
          'A drawer, a shelf, a tray. It does not need arranging.',
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: t.s1,
              child: _camera != null && _camera!.value.isInitialized
                  ? CameraPreview(_camera!)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _cameraError ?? 'Opening camera',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.text2, fontSize: 15),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _action(
          _working ? 'Capturing' : 'Take photo',
          _camera == null || _working ? null : _takePhoto,
        ),
      ),
      TextButton(
        onPressed: _choosePhoto,
        child: const Text('Choose a photo instead'),
      ),
      if (_cameraError != null)
        TextButton(
          onPressed: _openCamera,
          child: const Text('Try camera again'),
        ),
      const SizedBox(height: 16),
    ],
  );

  Widget _running(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(
        t,
        'Seeing what is there.',
        'This ends when the photo has been checked.',
      ),
      _card(
        t,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_working) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _working
                  ? 'Reading this photograph'
                  : 'This photograph could not be read.',
              style: TextStyle(color: t.ink, fontSize: 17),
            ),
          ],
        ),
      ),
      if (!_working) ...[
        const SizedBox(height: 20),
        _action('Try again', _extract),
        TextButton(
          onPressed: _cameraStep,
          child: const Text('Take another photo'),
        ),
      ],
    ],
  );

  Widget _review(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(
        t,
        '${_items.length} ${_items.length == 1 ? 'thing' : 'things'} found.',
        'Check the names. Fix anything it got wrong.',
      ),
      _card(
        t,
        Column(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.separator),
              SizedBox(
                height: AppTokens.rowHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _needsIdentity(_items[i])
                            ? '${_items[i].name.trim().isEmpty ? 'Needs a name' : _items[i].name}  /  Needs review'
                            : _items[i].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.ink, fontSize: 15),
                      ),
                    ),
                    Text(
                      '${_items[i].quantity}',
                      style: TextStyle(
                        color: t.ink,
                        fontFamily: 'IBMPlexMono',
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _fix(_items[i]),
                      child: const Text('Fix'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
      TextField(
        controller: _place,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Where are these?',
          hintText: 'Name a place you use',
        ),
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 22),
      _action(
        widget.saveFirstSpace
            ? (_working ? 'Remembering' : 'Remember these')
            : 'Close tour',
        _working || (widget.saveFirstSpace && _place.text.trim().isEmpty)
            ? null
            : _remember,
      ),
      TextButton(
        onPressed: _cameraStep,
        child: const Text('Take another photo'),
      ),
    ],
  );

  Widget _memory(AppTokens t) {
    final first = _saved.first;
    final lines = <(String, String)>[
      ('Where', first.spaceName ?? first.location),
      ('How many', '${first.quantity}'),
      if (first.category.trim().isNotEmpty) ('Kind', first.category),
      if (first.brand?.trim().isNotEmpty ?? false) ('Brand', first.brand!),
      if (first.partNumber?.trim().isNotEmpty ?? false)
        ('Part number', first.partNumber!),
      if (first.barcode?.trim().isNotEmpty ?? false)
        ('Barcode', first.barcode!),
      if (first.reorderPoint != null && first.reorderPoint! > 0)
        ('Reorder at', '${first.reorderPoint}'),
      for (final relation in _relationships)
        if ((relation['other_item'] as Map?)?['name'] != null ||
            (relation['project_kit'] as Map?)?['name'] != null)
          (
            (relation['kind'] ?? 'Connected to').toString().replaceAll(
              '_',
              ' ',
            ),
            ((relation['other_item'] as Map?)?['name'] ??
                    (relation['project_kit'] as Map?)?['name'])
                .toString(),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          t,
          'It remembers ${first.displayName}.',
          'Saved from your photograph.',
        ),
        _card(
          t,
          Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.separator),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          lines[i].$1,
                          style: TextStyle(color: t.text2, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          lines[i].$2,
                          style: TextStyle(color: t.ink, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_savedCount ${_savedCount == 1 ? 'object' : 'objects'} saved.',
          style: TextStyle(color: t.text2, fontSize: 14),
        ),
        if (_relationshipsLoading) ...[
          const SizedBox(height: 8),
          Text(
            'Checking connections',
            style: TextStyle(color: t.text2, fontSize: 13),
          ),
        ],
        if (_memoryError != null) ...[
          const SizedBox(height: 8),
          Text(
            'Connections could not be loaded.',
            style: TextStyle(color: t.text2, fontSize: 13),
          ),
        ],
        if (!_relationshipsLoading &&
            _memoryError == null &&
            _relationships.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No connections recorded yet.',
            style: TextStyle(color: t.text2, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        _action('Ask it something', _next),
      ],
    );
  }

  Widget _ask(AppTokens t) {
    final first = _saved.first;
    final place = first.spaceName ?? first.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(t, 'Ask about what you captured.'),
        _card(
          t,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where is ${first.displayName}?',
                style: TextStyle(color: t.ink, fontSize: 17),
              ),
              const SizedBox(height: 16),
              Text(
                '$place. You have ${first.quantity}.',
                style: TextStyle(color: t.text2, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (final row in const [
          ('Capture', 'Remember what you see'),
          ('Ask', 'Get an answer from your inventory'),
          ('Find', 'Locate what you own'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _card(
              t,
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      row.$1,
                      style: TextStyle(color: t.ink, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(color: t.text2, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        _action('Continue', _next),
      ],
    );
  }

  Widget _who(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(t, 'Who should it remember for?'),
      for (final choice in const [
        ('solo', 'Just me', 'One person, one memory'),
        ('team', 'A team', 'Places and objects shared with others'),
        ('organization', 'An organization', 'Several places and people'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _selectPersona(choice.$1),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.$2,
                      style: TextStyle(color: t.ink, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice.$3,
                      style: TextStyle(color: t.text2, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _import(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(
        t,
        'Already have a list?',
        'Bring an existing register into the place you just named.',
      ),
      _card(
        t,
        Text(
          'A spreadsheet can add objects to ${_place.text.trim()}.',
          style: TextStyle(color: t.ink, fontSize: 15),
        ),
      ),
      const SizedBox(height: 22),
      _action('Choose a spreadsheet', () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                ImportSheetPage(api: widget.api, location: _place.text.trim()),
          ),
        );
      }),
      TextButton(onPressed: _next, child: const Text('Continue')),
    ],
  );

  Widget _invite(AppTokens t) {
    final teamId = _selectedTeamId ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          t,
          'Who else is in it?',
          'Invitations can be sent to an existing team.',
        ),
        if (_teamsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_teams.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                t,
                Text(
                  _error == null
                      ? 'No team is connected yet. Create one from More, then invite people.'
                      : 'Teams could not be loaded.',
                  style: TextStyle(color: t.text2, fontSize: 15),
                ),
              ),
              if (_error != null)
                TextButton(
                  onPressed: _loadTeams,
                  child: const Text('Try again'),
                ),
            ],
          )
        else ...[
          Text('Choose a team', style: TextStyle(color: t.text2, fontSize: 14)),
          const SizedBox(height: 10),
          for (final team in _teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => setState(
                  () => _selectedTeamId = team['team_id']?.toString(),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: teamId == team['team_id']?.toString()
                      ? t.ink
                      : t.card,
                  foregroundColor: teamId == team['team_id']?.toString()
                      ? t.paper
                      : t.ink,
                ),
                child: Text((team['name'] ?? 'Team').toString()),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _inviteEmail,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 18),
          _action(
            _working ? 'Sending' : 'Send invitation',
            _working || teamId.isEmpty || _inviteEmail.text.trim().isEmpty
                ? null
                : _sendInvite,
          ),
        ],
        TextButton(onPressed: _next, child: const Text('Later')),
      ],
    );
  }

  Widget _policy(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(
        t,
        'Your photographs.',
        'Your organization can review its data choices in Settings.',
      ),
      _card(
        t,
        Text(
          'Original photos are kept with captured objects so a count can be checked against what the camera saw.',
          style: TextStyle(color: t.ink, fontSize: 15),
        ),
      ),
      const SizedBox(height: 22),
      _action('Continue', _next),
    ],
  );

  Widget _done(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(
        t,
        'It remembers $_savedCount ${_savedCount == 1 ? 'thing' : 'things'}.',
        'They are in ${_place.text.trim()}.',
      ),
      _card(
        t,
        Column(
          children: [
            for (final row in const [
              ('Next', 'Photograph another place.'),
              ('Then', 'Tell it what you are working on.'),
              ('After that', 'It starts telling you what needs attention.'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.$1,
                        style: TextStyle(color: t.text2, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: TextStyle(color: t.ink, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _action(_working ? 'Opening' : 'Open FindEZ', _working ? null : _finish),
    ],
  );
}

class _MemoryPainter extends CustomPainter {
  const _MemoryPainter(this.t);
  final AppTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = t.card;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      paint,
    );
    final outlines = [
      Rect.fromLTWH(size.width * .13, 40, 58, 65),
      Rect.fromLTWH(size.width * .36, 55, 80, 46),
      Rect.fromLTWH(size.width * .68, 33, 46, 82),
    ];
    for (var i = 0; i < outlines.length; i++) {
      final r = outlines[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(9)),
        Paint()..color = i == 1 ? t.accentSoft : t.s2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(9)),
        Paint()
          ..color = i == 1 ? t.accentLine : t.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MemoryPainter oldDelegate) => oldDelegate.t != t;
}
