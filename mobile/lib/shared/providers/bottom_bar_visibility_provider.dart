import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether the floating nav bar is shown over the current screen.
///
/// The shell watches this provider; detail / push-route screens flip it to
/// `false` in `initState` and back to `true` in `dispose` so the bar slides
/// out of the way (Apple TabView push pattern) instead of floating on top of
/// dialog-like sub-screens.
final bottomBarVisibleProvider = StateProvider<bool>((ref) => true);
