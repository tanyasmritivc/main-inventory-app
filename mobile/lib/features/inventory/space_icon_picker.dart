import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/space_icon_preferences.dart';
import 'package:mobile/core/ui/app_text.dart';

class SpaceIconOption {
  const SpaceIconOption(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

// Persist names, never font code points (which can change between SDKs).
const spaceIconOptions = [
  SpaceIconOption('box', 'Box', CupertinoIcons.archivebox),
  SpaceIconOption('home', 'Home', CupertinoIcons.house),
  SpaceIconOption('tools', 'Tools', CupertinoIcons.wrench),
  SpaceIconOption('gear', 'Gear', CupertinoIcons.gear_alt),
  SpaceIconOption('bolt', 'Electronics', CupertinoIcons.bolt),
  SpaceIconOption('computer', 'Computer', CupertinoIcons.desktopcomputer),
  SpaceIconOption('car', 'Garage', CupertinoIcons.car_detailed),
  SpaceIconOption('books', 'Books', CupertinoIcons.book),
  SpaceIconOption('kitchen', 'Kitchen', CupertinoIcons.cart),
  SpaceIconOption('cup', 'Coffee', Icons.coffee_outlined),
  SpaceIconOption('bed', 'Bedroom', CupertinoIcons.bed_double),
  SpaceIconOption('bag', 'Bag', CupertinoIcons.bag),
  SpaceIconOption('briefcase', 'Office', CupertinoIcons.briefcase),
  SpaceIconOption('folder', 'Folder', CupertinoIcons.folder),
  SpaceIconOption('people', 'Shared', CupertinoIcons.person_2),
  SpaceIconOption('gift', 'Gifts', CupertinoIcons.gift),
  SpaceIconOption('leaf', 'Garden', Icons.eco_outlined),
  SpaceIconOption('sport', 'Sports', CupertinoIcons.sportscourt),
  SpaceIconOption('camera', 'Camera', CupertinoIcons.camera),
  SpaceIconOption('music', 'Music', CupertinoIcons.music_note_2),
  SpaceIconOption('art', 'Art', CupertinoIcons.paintbrush),
  SpaceIconOption('health', 'Health', CupertinoIcons.heart),
  SpaceIconOption('travel', 'Travel', CupertinoIcons.airplane),
  SpaceIconOption('star', 'Favorites', CupertinoIcons.star),
];

IconData automaticSpaceIcon(String name) {
  final value = name.toLowerCase();
  if (['robot', 'ftc', 'frc', 'electronics'].any(value.contains)) {
    return CupertinoIcons.gear_alt_fill;
  }
  if (['tool', 'hardware', 'fastener', 'workshop'].any(value.contains)) {
    return CupertinoIcons.wrench;
  }
  if (['food', 'kitchen', 'grocery'].any(value.contains)) {
    return CupertinoIcons.cart;
  }
  if (['home', 'house', 'personal'].any(value.contains)) {
    return CupertinoIcons.house;
  }
  if (['book', 'school', 'class'].any(value.contains)) {
    return CupertinoIcons.book;
  }
  if (['car', 'vehicle'].any(value.contains)) {
    return CupertinoIcons.car_detailed;
  }
  return CupertinoIcons.archivebox;
}

IconData _iconFor(String? id, IconData fallback) =>
    spaceIconOptions
        .where((option) => option.id == id)
        .map((option) => option.icon)
        .firstOrNull ??
    fallback;

/// The whole 44pt leading target opens the picker, not the Space route.
class SpaceIconButton extends StatefulWidget {
  const SpaceIconButton({
    super.key,
    required this.spaceId,
    required this.spaceName,
    this.namespace = 'space',
    this.fallbackIcon,
    this.preferences,
    this.accountId,
  });

  final String spaceId;
  final String spaceName;
  final String namespace;
  final IconData? fallbackIcon;
  final SpaceIconPreferences? preferences;
  final String? Function()? accountId;

  @override
  State<SpaceIconButton> createState() => _SpaceIconButtonState();
}

class _SpaceIconButtonState extends State<SpaceIconButton> {
  late SpaceIconController _controller;
  StreamSubscription<AuthState>? _authSub;
  bool _pickerOpen = false;

  String? _accountId() => widget.accountId != null
      ? widget.accountId!()
      : Supabase.instance.client.auth.currentUser?.id;

  void _createController() {
    _controller = SpaceIconController(
      preferences: widget.preferences ?? SpaceIconPreferences.instance,
      accountId: _accountId,
      namespace: widget.namespace,
      id: widget.spaceId,
      validIconIds: spaceIconOptions.map((option) => option.id).toSet(),
    );
    unawaited(_controller.load());
  }

  @override
  void initState() {
    super.initState();
    _createController();
    if (widget.accountId == null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        unawaited(_controller.load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant SpaceIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.namespace != widget.namespace ||
        oldWidget.preferences != widget.preferences) {
      _controller.dispose();
      _createController();
    } else {
      unawaited(_controller.load());
    }
  }

  Future<void> _chooseIcon() async {
    if (_pickerOpen) return;
    _pickerOpen = true;
    HapticFeedback.selectionClick();
    // Retry a failed read rather than overwriting an unread stored choice.
    await _controller.load();
    if (!mounted) return;
    final controller = _controller;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SpaceIconPicker(
        controller: controller,
        spaceName: widget.spaceName,
        fallbackIcon:
            widget.fallbackIcon ?? automaticSpaceIcon(widget.spaceName),
      ),
    );
    if (mounted) _pickerOpen = false;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => IconButton(
      tooltip: 'Change icon for ${widget.spaceName}',
      onPressed: widget.spaceId.trim().isEmpty ? null : _chooseIcon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(
        _iconFor(
          _controller.accountIsCurrent ? _controller.selectedIconId : null,
          widget.fallbackIcon ?? automaticSpaceIcon(widget.spaceName),
        ),
        size: 22,
        color: AppTheme.textSecondary(context),
      ),
    ),
  );
}

class SpaceIconPicker extends StatefulWidget {
  const SpaceIconPicker({
    super.key,
    required this.controller,
    required this.spaceName,
    required this.fallbackIcon,
  });
  final SpaceIconController controller;
  final String spaceName;
  final IconData fallbackIcon;

  @override
  State<SpaceIconPicker> createState() => _SpaceIconPickerState();
}

class _SpaceIconPickerState extends State<SpaceIconPicker> {
  late final String? _actor = widget.controller.actor;
  late String? _draft = widget.controller.selectedIconId;
  late bool _draftInitialized = widget.controller.loaded;
  String _query = '';

  bool get _sameAccount =>
      widget.controller.accountIsCurrent && widget.controller.actor == _actor;

  Future<void> _save() async {
    if (!_sameAccount) return;
    final saved = await widget.controller.setIcon(_draft);
    if (!mounted || !_sameAccount || !saved) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      if (!_draftInitialized && controller.loaded) {
        _draft = controller.selectedIconId;
        _draftInitialized = true;
      }
      final enabled = controller.canSave && _sameAccount;
      final options = spaceIconOptions.where(
        (option) => option.label.toLowerCase().contains(_query.toLowerCase()),
      );
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height *
                (MediaQuery.textScalerOf(context).scale(14) > 22 ? .92 : .75),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Space icon',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          widget.spaceName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          'Your icon choice is saved for this account on this device only.',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search icons',
                            prefixIcon: Icon(CupertinoIcons.search),
                          ),
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          style: AppTypography.bodyStyleOf(context),
                        ),
                        const SizedBox(height: 12),
                        _choice(
                          id: null,
                          label: 'Automatic',
                          icon: widget.fallbackIcon,
                          enabled: enabled,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final scale =
                                MediaQuery.textScalerOf(context).scale(14) / 14;
                            final columns = scale > 1.6
                                ? 1
                                : scale > 1.15 || constraints.maxWidth < 300
                                ? 2
                                : 3;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 8) /
                                columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in options)
                                  SizedBox(
                                    width: width,
                                    child: _choice(
                                      id: option.id,
                                      label: option.label,
                                      icon: option.icon,
                                      enabled: enabled,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        if (options.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: AppText(
                              'No matching icons. Try another name.',
                            ),
                          ),
                        if (!_sameAccount)
                          AppText(
                            _actor == null
                                ? 'Sign in to choose a personal Space icon.'
                                : 'Account changed. Close this picker and reopen it.',
                          ),
                        if (controller.error != null) ...[
                          const SizedBox(height: 16),
                          AppText(
                            controller.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          if (!controller.loaded)
                            TextButton(
                              onPressed: () => controller.load(force: true),
                              child: const AppText('Retry'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const AppText('Cancel'),
                      ),
                      FilledButton(
                        onPressed: enabled ? _save : null,
                        child: AppText(
                          controller.saving ? 'Saving...' : 'Save icon',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _choice({
    required String? id,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    final selected = id == _draft;
    return MergeSemantics(
      key: ValueKey('space-icon-${id ?? 'automatic'}'),
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          onPressed: enabled
              ? () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() => _draft = id);
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary(context),
            backgroundColor: selected
                ? AppTheme.surface2(context)
                : AppTheme.surface(context),
            side: BorderSide(
              color: selected
                  ? AppTheme.textPrimary(context)
                  : AppTheme.border(context),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 8),
              AppText(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
