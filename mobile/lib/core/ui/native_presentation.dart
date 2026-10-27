import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@visibleForTesting
bool? debugNativePresentationOverride;
bool get usesNativePresentation =>
    debugNativePresentationOverride ?? (!kIsWeb && Platform.isIOS);
typedef NativeSheetAction =
    Future<Map<String, dynamic>> Function(String id, bool? value);

/// A Flutter route owns each UIKit presentation so back/disposal cannot leave an
/// orphan sheet above another account or screen. Only presentation crosses this
/// bridge; callers retain authorization, persistence and error handling.
class NativePresentation {
  static const channel = MethodChannel('com.findez.app/presentation');
  static int _next = 0;
  static final _handlers = <String, NativeSheetAction>{};
  static bool _initialized = false;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> model,
    NativeSheetAction? onAction,
  }) {
    if (!_initialized) {
      _initialized = true;
      channel.setMethodCallHandler((call) async {
        if (call.method != 'action' || call.arguments is! Map) return null;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final handler = _handlers[args['token']];
        if (handler == null || args['id'] is! String) return null;
        return handler(args['id'] as String, args['value'] as bool?);
      });
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final token = 'presentation-${++_next}';
    return Navigator.of(context, rootNavigator: true).push(
      _NativeRoute(token, {
        ...model,
        'token': token,
        'dark': Theme.of(context).brightness == Brightness.dark,
      }, onAction),
    );
  }
}

class _NativeRoute extends PopupRoute<Map<String, dynamic>> {
  _NativeRoute(this.token, this.model, this.onAction);
  final String token;
  final Map<String, dynamic> model;
  final NativeSheetAction? onAction;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _NativeHost(route: this);
}

class _NativeHost extends StatefulWidget {
  const _NativeHost({required this.route});
  final _NativeRoute route;
  @override
  State<_NativeHost> createState() => _NativeHostState();
}

class _NativeHostState extends State<_NativeHost> {
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route.onAction != null) {
      NativePresentation._handlers[route.token] = route.onAction!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _present());
  }

  Future<void> _present() async {
    if (!mounted) return;
    Map<String, dynamic>? result;
    try {
      result = await NativePresentation.channel
          .invokeMapMethod<String, dynamic>('present', widget.route.model);
    } on PlatformException {
      result = {'error': 'Could not open this control. Please try again.'};
    } on MissingPluginException {
      result = {'error': 'This control needs the latest app build.'};
    }
    _finished = true;
    if (mounted) widget.route.navigator?.removeRoute(widget.route, result);
  }

  @override
  void dispose() {
    NativePresentation._handlers.remove(widget.route.token);
    if (!_finished) {
      unawaited(
        NativePresentation.channel.invokeMethod<void>('dismiss', {
          'token': widget.route.token,
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Future<bool> showAppConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  if (usesNativePresentation) {
    final result = await NativePresentation.show(
      context,
      model: {
        'kind': 'alert',
        'title': title,
        'message': message,
        'confirmLabel': confirmLabel,
        'destructive': destructive,
      },
    );
    if (context.mounted && result?['error'] is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result!['error'] as String)));
    }
    return result?['action'] == 'confirm';
  }
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ==
      true;
}

Future<String?> showNativeNamePrompt(
  BuildContext context, {
  required String title,
  required String placeholder,
  String? initial,
}) async {
  final result = await NativePresentation.show(
    context,
    model: {
      'kind': 'alert',
      'title': title,
      'input': true,
      'placeholder': placeholder,
      'initial': initial ?? '',
      'confirmLabel': 'Save',
    },
  );
  if (!context.mounted) return null;
  if (result?['error'] is String) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result!['error'] as String)));
  }
  final text = (result?['text'] as String?)?.trim();
  return result?['action'] == 'confirm' && text != null && text.isNotEmpty
      ? text
      : null;
}

Future<String?> showNativeChoices(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> rows,
}) async {
  final selected = await NativePresentation.show(
    context,
    model: {
      'title': title,
      'sections': [
        {'rows': rows},
      ],
    },
  );
  if (!context.mounted) return null;
  if (selected?['error'] is String) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(selected!['error'] as String)));
  }
  final id = selected?['action'];
  return id is String && rows.any((r) => r['id'] == id) ? id : null;
}
