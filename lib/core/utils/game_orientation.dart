import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The App is portrait-only ([appOrientations]); a game page also follows
/// the phone into landscape ([gameOrientations]).
const appOrientations = [DeviceOrientation.portraitUp];
const gameOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Lets its subtree (a game web view) rotate with the phone and hides the
/// system bars while it is landscape. Leaving the subtree (pop, switching the
/// home tab away from the town) puts the portrait lock and the bars back.
///
/// Only a wrapper: [child] keeps its place in the tree across a rotation, so
/// a web view inside is not reloaded.
class GameOrientationScope extends StatefulWidget {
  const GameOrientationScope({super.key, required this.child});

  final Widget child;

  @override
  State<GameOrientationScope> createState() => _GameOrientationScopeState();
}

class _GameOrientationScopeState extends State<GameOrientationScope> {
  /// Scopes alive at once (a game page can open over the town tab): the
  /// portrait lock comes back only when the last one leaves.
  static int _active = 0;

  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    _active++;
    SystemChrome.setPreferredOrientations(gameOrientations);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape == _immersive) return;
    _immersive = landscape;
    if (landscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  void dispose() {
    _active--;
    if (_active == 0) {
      SystemChrome.setPreferredOrientations(appOrientations);
    }
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
