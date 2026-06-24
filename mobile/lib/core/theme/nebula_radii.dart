import 'package:flutter/material.dart';

enum NebulaRadiusRole {
  micro,
  compactControl,
  control,
  card,
  panel,
  modal,
  sheet,
  nav,
  hero,
  pill,
}

extension NebulaRadiusRoleGeometry on NebulaRadiusRole {
  double get value => switch (this) {
        NebulaRadiusRole.micro => NebulaRadii.micro,
        NebulaRadiusRole.compactControl => NebulaRadii.compactControl,
        NebulaRadiusRole.control => NebulaRadii.control,
        NebulaRadiusRole.card => NebulaRadii.card,
        NebulaRadiusRole.panel => NebulaRadii.panel,
        NebulaRadiusRole.modal => NebulaRadii.modal,
        NebulaRadiusRole.sheet => NebulaRadii.sheet,
        NebulaRadiusRole.nav => NebulaRadii.nav,
        NebulaRadiusRole.hero => NebulaRadii.hero,
        NebulaRadiusRole.pill => NebulaRadii.pill,
      };

  BorderRadius get borderRadius => BorderRadius.circular(value);
}

/// Semantic corner geometry for application surfaces and controls.
abstract final class NebulaRadii {
  static const double micro = 4;
  static const double compactControl = 8;
  static const double control = 12;
  static const double card = 18;
  static const double panel = 24;
  static const double modal = 24;
  static const double sheet = 24;
  static const double nav = 24;
  static const double hero = 32;
  static const double pill = 999;

  static const BorderRadius compactControlBorder =
      BorderRadius.all(Radius.circular(compactControl));
  static const BorderRadius controlBorder =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius panelBorder =
      BorderRadius.all(Radius.circular(panel));
  static const BorderRadius modalBorder =
      BorderRadius.all(Radius.circular(modal));
  static const BorderRadius sheetTopBorder =
      BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius navBorder = BorderRadius.all(Radius.circular(nav));
  static const BorderRadius heroBorder =
      BorderRadius.all(Radius.circular(hero));
  static const BorderRadius pillBorder =
      BorderRadius.all(Radius.circular(pill));
}
