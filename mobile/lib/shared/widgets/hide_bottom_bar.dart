import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bottom_bar_visibility_provider.dart';

/// Hides the floating nav bar while this widget is mounted.
///
/// Wrap the body of any push/detail screen with [HideBottomBar] (or invoke
/// it from initState/dispose via [HideBottomBar.useEffect]) so the bar
/// slides out of the way on entry and slides back on exit — same pattern as
/// `tabBar.isVisible = false` in the Apple TabView reference architecture.
class HideBottomBar extends ConsumerStatefulWidget {
  final Widget child;

  const HideBottomBar({super.key, required this.child});

  @override
  ConsumerState<HideBottomBar> createState() => _HideBottomBarState();
}

class _HideBottomBarState extends ConsumerState<HideBottomBar> {
  @override
  void initState() {
    super.initState();
    // Defer to after the first frame so we don't write to a provider during
    // the parent's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bottomBarVisibleProvider.notifier).state = false;
    });
  }

  @override
  void dispose() {
    // Restore the bar — read with .read on the container since `ref` is still
    // valid in dispose for ConsumerStatefulWidget.
    ref.read(bottomBarVisibleProvider.notifier).state = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
