import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'skeleton.dart';

/// Shows the navigation placeholder during the existing route transition only.
/// Does not delay a route or issue a request; real loaders take over if needed.
class PageArrivalTransitions extends PageTransitionsBuilder {
  const PageArrivalTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final content = AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final show =
            animation.status == AnimationStatus.forward &&
            animation.value < .75 &&
            !MediaQuery.disableAnimationsOf(context) &&
            !MediaQuery.accessibleNavigationOf(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (show)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const SafeArea(child: SkeletonPage()),
                  ),
                ),
              ),
          ],
        );
      },
    );
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      content,
    );
  }
}
