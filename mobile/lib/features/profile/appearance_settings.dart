import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/appearance_controller.dart';
import '../../core/app_theme.dart';
import 'package:mobile/core/ui/app_text.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key, this.controller});
  final AppearanceController? controller;

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  AppearanceController? _controller;
  bool _ownsController = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(AppearanceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) _bindController();
  }

  void _bindController() {
    final scoped = widget.controller ?? AppearanceScope.maybeOf(context);
    if (_controller != null && (scoped == null || scoped == _controller)) {
      return;
    }
    if (_ownsController) _controller?.dispose();
    _ownsController = scoped == null;
    _controller = scoped ?? AppearanceController();
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  Widget _choices<T>({
    required String label,
    required Map<T, String> choices,
    required T selected,
    required void Function(T)? onSelected,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        style: TextStyle(
          color: AppTheme.textPrimary(context),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: choices.entries
            .map(
              (entry) => ChoiceChip(
                label: AppText(entry.value),
                selected: selected == entry.key,
                onSelected: onSelected == null
                    ? null
                    : (chosen) {
                        if (chosen) onSelected(entry.key);
                      },
                showCheckmark: false,
                selectedColor: AppTheme.textPrimary(context),
                backgroundColor: AppTheme.surface2(context),
                disabledColor: selected == entry.key
                    ? AppTheme.textPrimary(context)
                    : AppTheme.surface2(context),
                labelStyle: TextStyle(
                  color: selected == entry.key
                      ? (AppTheme.isDark(context)
                            ? AppTheme.darkBg
                            : Colors.white)
                      : AppTheme.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(color: AppTheme.border(context)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            )
            .toList(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller!,
    builder: (context, _) {
      final controller = _controller!;
      final enabled = controller.loaded && !controller.saving;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 26, 0, 9),
            child: AppText(
              'Appearance',
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border(context), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _choices<ThemeMode>(
                  label: 'Theme',
                  choices: const {
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                    ThemeMode.system: 'System',
                  },
                  selected: controller.themeMode,
                  onSelected: enabled
                      ? (mode) => unawaited(controller.setThemeMode(mode))
                      : null,
                ),
                const SizedBox(height: 8),
                AppText(
                  'System follows your phone\'s appearance.',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: AppTheme.border(context)),
                ),
                _choices<AppTextSize>(
                  label: 'Text size',
                  choices: {
                    for (final size in AppTextSize.values) size: size.label,
                  },
                  selected: controller.textSize,
                  onSelected: enabled
                      ? (size) => unawaited(controller.setTextSize(size))
                      : null,
                ),
                const SizedBox(height: 8),
                AppText(
                  'Default follows your phone. Other sizes adjust it without '
                  'turning off accessibility scaling.',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Preview',
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        'The right item, in the right place.',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.saving) ...[
                  const SizedBox(height: 12),
                  const AppText('Saving appearance settings...'),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: AppText(
                      controller.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}
