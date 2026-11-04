import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'founding_access_sheet.dart';
import 'founding_access_store.dart';

/// Emitted by the mounted Ask destination after onboarding/navigation resolves.
class FoundingAskReady extends Notification {
  const FoundingAskReady(this.accountId);
  final String? accountId;
}

class FoundingAccessGate extends StatefulWidget {
  const FoundingAccessGate({
    super.key,
    required this.user,
    required this.child,
    this.store,
  });
  final User user;
  final Widget child;
  final FoundingAccessStore? store;
  @override
  State<FoundingAccessGate> createState() => _FoundingAccessGateState();
}

class _FoundingAccessGateState extends State<FoundingAccessGate> {
  late final _store = widget.store ?? FoundingAccessStore.instance;
  Timer? _delay;
  bool _askReady = false, _open = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _store.addListener(_check);
  }

  @override
  void didUpdateWidget(covariant FoundingAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      ++_generation;
      _delay?.cancel();
      _askReady = false;
      _open = false;
    } else if (oldWidget.user.emailConfirmedAt !=
        widget.user.emailConfirmedAt) {
      _check();
    }
  }

  void _check() {
    if (!_askReady || _open || !mounted) return;
    final generation = ++_generation;
    _delay?.cancel();
    unawaited(() async {
      try {
        final eligible = await _store.shouldShow(widget.user);
        if (!eligible || !mounted || generation != _generation) return;
        _delay = Timer(const Duration(milliseconds: 500), () {
          if (!mounted ||
              generation != _generation ||
              !(ModalRoute.of(context)?.isCurrent ?? true)) {
            return;
          }
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _open = true);
        });
      } catch (_) {
        debugPrint('Founding Access local receipt could not be read.');
      }
    }());
  }

  @override
  void dispose() {
    ++_generation;
    _delay?.cancel();
    _store.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<FoundingAskReady>(
    onNotification: (notification) {
      if (notification.accountId == widget.user.id) {
        _askReady = true;
        _check();
      }
      return false;
    },
    child: Stack(
      children: [
        ExcludeFocus(
          excluding: _open,
          child: ExcludeSemantics(excluding: _open, child: widget.child),
        ),
        if (_open)
          Positioned.fill(
            child: FoundingAccessSheet(
              onDismiss: () => unawaited(_store.dismiss(widget.user.id)),
              onClosed: () {
                if (mounted) setState(() => _open = false);
              },
            ),
          ),
      ],
    ),
  );
}
