import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;

/// Navigation never pretends to load data. Each page owns its real loading state.
class PageArrivalTransitions extends PageTransitionsBuilder {
  const PageArrivalTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

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
    final content = reduced
        ? child
        : FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
            child: child,
          );
    // Retain Flutter's iOS edge-back gesture and route lifecycle. Stationary
    // Cupertino animations avoid combining a slide with the short fade.
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      const AlwaysStoppedAnimation<double>(1),
      const AlwaysStoppedAnimation<double>(0),
      content,
    );
  }
}
