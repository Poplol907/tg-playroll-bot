/// Canonical geometry for application shell chrome.
///
/// Hardware safe areas remain owned by [SafeArea]. These values describe only
/// application chrome rendered inside those safe areas.
abstract final class AppChromeMetrics {
  static const double monthControlHeight = 38;
  static const double mobileTopIslandVisualHeight = monthControlHeight;
  static const double mobileTopIslandOuterVerticalGap = 8;
  static const double mobileTopIslandExtent =
      mobileTopIslandVisualHeight + (mobileTopIslandOuterVerticalGap * 2);

  static const double routeContentTopReservation = mobileTopIslandExtent;
  static const double floatingBottomNavReservation = 84;

  static const double mobileTopIslandHorizontalInset = 16;
  static const double monthPillMaxWidth = 240;
}
