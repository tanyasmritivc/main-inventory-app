import 'dart:async';
import 'package:flutter/widgets.dart';

/// Optional instrumentation shared only by screens opened from a notification.
class NotificationVisit {
  NotificationVisit(this.send, {this.canMarkReviewed = false});
  final Future<void> Function(String event) send;
  final bool canMarkReviewed;
  final _seen = <String>{};
  Future<void> _pending = Future.value();

  void record(String event) {
    if (_seen.add(event)) _pending = _pending.then((_) => send(event));
  }

  void shown(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        record('destination_opened');
      }
    });
  }
}
