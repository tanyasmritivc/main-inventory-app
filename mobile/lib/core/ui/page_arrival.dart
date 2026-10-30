import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;

/// Navigation never pretends to load data. Each page owns its real loading state.
class PageArrivalTransitions extends PageTransitionsBuilder {
  const PageArrivalTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    // Use the route's real animation, including interactive back gestures.
    // Whole-page opacity also causes expensive compositing of glass/platform views.
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      reduced ? const AlwaysStoppedAnimation<double>(1) : animation,
      reduced ? const AlwaysStoppedAnimation<double>(0) : secondaryAnimation,
      child,
    );
  }
}
