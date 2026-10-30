import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'navigation_motion.dart';

/// Framework-managed route lifecycle, with a restrained, stationary dissolve.
class PageArrivalTransitions extends PageTransitionsBuilder {
  const PageArrivalTransitions();
  @override
  Duration get transitionDuration => NavigationMotion.duration;
  @override
  Duration get reverseTransitionDuration => NavigationMotion.duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => ValueListenableBuilder<MotionPreferences>(
    valueListenable: NativeMotionPreferences.instance,
    child: child,
    builder: (context, preferences, child) {
      final animate = NavigationMotion.enabled(context, preferences);
      // Let Flutter's native-style route driver own interactive edge-back. It
      // follows the finger and settles cancellation without a second animation.
      final gesture = route.popGestureInProgress;
      final content = !animate || gesture
          ? child!
          : AnimatedBuilder(
              animation: Listenable.merge([animation, secondaryAnimation]),
              child: child,
              builder: (context, child) => Opacity(
                opacity:
                    NavigationMotion.incoming(animation.value) *
                    NavigationMotion.outgoing(secondaryAnimation.value),
                child: child,
              ),
            );
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        route,
        context,
        gesture && animate
            ? animation
            : const AlwaysStoppedAnimation<double>(1),
        gesture && animate
            ? secondaryAnimation
            : const AlwaysStoppedAnimation<double>(0),
        content,
      );
    },
  );
}
