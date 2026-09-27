import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/ui/visual_surfaces.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.onOpen, required this.onWorkspace});

  final void Function(String destination) onOpen;
  final VoidCallback onWorkspace;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        TextButton(
          onPressed: onWorkspace,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppTokens.of(context).ink,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 54),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('My inventory', style: text.headlineMedium),
              const SizedBox(width: 8),
              Text('⌄', style: text.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _group(context, 'Your world', [
          ('Places', 'places'),
          ('All objects', 'objects'),
          ('Documents', 'documents'),
          ('Labels', 'labels'),
        ]),
        _group(context, 'What you are doing', [
          ('Projects', 'projects'),
          ('Supplies', 'supplies'),
          ('Checkouts', 'checkouts'),
        ]),
        _group(context, 'Keeping it true', [
          ('Review', 'review'),
          ('Activity', 'activity'),
          ('Inbox', 'inbox'),
        ]),
        _group(context, 'You', [
          ('Workspaces', 'workspaces'),
          ('Shared spaces', 'sharing'),
          ('Profile', 'profile'),
          ('Settings', 'settings'),
        ]),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    List<(String, String)> destinations,
  ) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(
              color: t.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          GroupedSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < destinations.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: t.separator),
                  Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => onOpen(destinations[index].$2),
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              destinations[index].$1,
                              style: text.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
