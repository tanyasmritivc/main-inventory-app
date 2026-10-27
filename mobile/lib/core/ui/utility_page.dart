import 'package:flutter/material.dart';
import 'app_text.dart';

/// Shared presentation for secondary pages, without changing the main shell.
class UtilityPage extends StatelessWidget {
  const UtilityPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.colorScheme.outlineVariant,
        width: .5,
      ),
    );
    return AppTypography(
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: AppText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
            ),
            centerTitle: true,
            actions: actions,
          ),
          body: SafeArea(top: false, child: body),
        ),
      ),
    );
  }
}

class UtilitySection extends StatelessWidget {
  const UtilitySection(this.title, {super.key, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, style: Theme.of(context).textTheme.titleSmall),
        if (description != null) ...[
          const SizedBox(height: 5),
          UtilityHint(description!),
        ],
      ],
    ),
  );
}

class UtilityHint extends StatelessWidget {
  const UtilityHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => AppText(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.5,
    ),
  );
}

class UtilityCard extends StatelessWidget {
  const UtilityCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: .5,
      ),
    ),
    child: child,
  );
}

class UtilityEmpty extends StatelessWidget {
  const UtilityEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      children: [
        Icon(
          icon,
          size: 26,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        AppText(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        AppText(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
