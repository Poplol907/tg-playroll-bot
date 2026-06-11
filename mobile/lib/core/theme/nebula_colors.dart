import 'package:flutter/material.dart';

abstract class NebulaColors {
  // ── Backgrounds (layered depth — never pure black) ──────────────────────────
  static const Color deepVoid = Color(0xFF0B1838); // Cosmic Ink
  static const Color spaceBlack =
      Color(0xFF0F1528); // Slightly lighter than void
  static const Color depthMid = Color(0xFF1B2444); // Mid background
  static const Color depthNear = Color(0xFF283460); // Elevated surfaces

  // ── Primary accents ─────────────────────────────────────────────────────────
  static const Color nebulaPurple = Color(0xFF8B5CF6); // Vivid violet
  static const Color stellarBlue = Color(0xFF146CFF); // Saturated action blue
  static const Color auroraCyan = Color(0xFF009BD6); // Crisp cyan accent
  static const Color milkyGlow = Color(0xFFC8DDF5); // Milky Glow

  // ── Secondary accents ───────────────────────────────────────────────────────
  static const Color plasmaPink = Color(0xFFFF5FD2); // Creative energy
  static const Color cosmicRose = Color(0xFFFF8AB8); // Emotional, errors

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color successMint = Color(0xFF00A878); // attended
  static const Color warningAmber = Color(0xFFF59E0B); // cancelled / debt
  static const Color errorRose = Color(0xFFE11D48); // missed

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color softWhite = Color(0xFFC8DDF5); // Primary text (Milky Glow)
  static const Color mistWhite =
      Color(0xB8FFFFFF); // Metallic secondary — readable on glass
  static const Color dimText = Color(0xFF8899BB); // Muted
  static const Color ghostText = Color(0xFF4A5568); // Disabled / very muted

  // ── Warm pearl tint — the "sandy" feel the user loves ───────────────────────
  // A very subtle warm cream overlay. Used as the glass tint on ALL surfaces
  // so every island feels unified. Barely perceptible on its own but consistent.
  static const Color warmPearl =
      Color(0x1AFFF8E7); // 10% warm cream (bumped for ASCII bg)
  static const Color warmPearlBright =
      Color(0x28FFF3D6); // 16% — hover / active states
  static const Color warmPearlBorder =
      Color(0x38FFE8B0); // 22% — warm border line

  // ── Surfaces (Frosted glass — white-tinted, not dark-tinted) ────────────────
  // Frosted glass uses a light white tint so the blurred background reads as
  // a diffuse milky haze rather than a dark smoked-glass panel.
  // NebulaSurface now renders its own frost layers — these constants are used
  // by other raw Container widgets (modals, sheets, dropdowns) that have their
  // own BackdropFilter but don't go through NebulaSurface.
  static const Color nebulaSurface =
      Color(0x18FFFFFF); //  9% white frost — panels
  static const Color denseNebulaSurface =
      Color(0x26FFFFFF); // 15% white frost — modals/forms
  static const Color surfaceBorder =
      Color(0x28FFFFFF); // 16% white — default border
  static const Color surfaceBorderBright =
      Color(0x42FFFFFF); // 26% white — active/hover border

  // ── Lesson status ───────────────────────────────────────────────────────────
  static Color lessonStatus(String status) => switch (status.toLowerCase()) {
        'attended' => successMint,
        'missed' => errorRose,
        'cancelled' => warningAmber,
        _ => stellarBlue,
      };

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient coreNebula = LinearGradient(
    colors: [nebulaPurple, stellarBlue, auroraCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quietDepth = LinearGradient(
    colors: [spaceBlack, depthMid, depthNear],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successBloom = LinearGradient(
    colors: [successMint, auroraCyan],
  );

  static const LinearGradient personalZone = LinearGradient(
    colors: [nebulaPurple, Color(0xFFA066FF), cosmicRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warm pearl glass gradient — used in NebulaSurface for unified sandy tint
  static const LinearGradient warmGlass = LinearGradient(
    colors: [warmPearlBright, warmPearl],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
