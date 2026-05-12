# NEBULA DESIGN SKILL — Cosmo Studio

> **Core formula:** Nebula is not glass in space. It is liquid nebula shaped into interface.

Reference this file in all future UI work on this project.

---

## 1. Core Identity

The UI must feel like:
- A **single living cosmic environment** — not disconnected screens
- **Soft luminous matter held in shape** — Nebula Material, not glass or flat dark
- **Premium, calm, immersive** — atmospheric beauty that serves clarity
- **Tactile and spatial** — light reacts, navigation preserves direction

Emotional tone: **calm · premium · atmospheric · immersive · intelligent · restrained**

This is a **calendar-first app**. Every design decision must support: time awareness, schedule clarity, event readability. The calendar is not one screen — it is the product's core logic.

Anti-identities to actively reject:
- Generic glassmorphism (flat `0x0AFFFFFF` surfaces)
- Cyberpunk / neon HUD aesthetics
- Random per-screen star wallpapers
- Cartoon liquid blobs or gimmicky VFX
- Pure `#000000` black backgrounds

---

## 2. Product Interpretation (Calendar-Centered Flutter App)

- The teacher opens the app to understand their month. Calendar = home.
- All effects serve comprehension, not decoration.
- Status colors (attended/missed/cancelled) are functional language, not decoration.
- Modals emerge from nebula depth — they don't slam over the screen.
- The bottom nav connects three sections of one world, not three separate apps.

---

## 3. Visual Principles

### Color Tokens

```dart
abstract class NebulaColors {
  // Backgrounds (layered depth — never pure black)
  static const Color deepVoid    = Color(0xFF050816);  // Far background
  static const Color spaceBlack  = Color(0xFF0B1020);  // Mid background
  static const Color depthMid    = Color(0xFF141A33);  // Near background
  static const Color depthNear   = Color(0xFF1D2450);  // Elevated surfaces

  // Primary accents
  static const Color nebulaPurple = Color(0xFF6F4CFF); // Personal zone, depth
  static const Color stellarBlue  = Color(0xFF3BA7FF); // Navigation, primary action
  static const Color auroraCyan   = Color(0xFF6CF7FF); // Focus, confirmation

  // Secondary accents
  static const Color plasmaPink   = Color(0xFFFF5FD2); // Creative energy
  static const Color cosmicRose   = Color(0xFFFF8AB8); // Emotional, some errors

  // Semantic
  static const Color successMint  = Color(0xFF73FFC7); // attended
  static const Color warningAmber = Color(0xFFFFB347); // cancelled / debt
  static const Color errorRose    = Color(0xFFFF6B8F); // missed

  // Text
  static const Color softWhite    = Color(0xFFF5F7FF); // Primary text
  static const Color mistWhite    = Color(0xB8FFFFFF); // Secondary (72%)
  static const Color dimText      = Color(0xFF8899BB); // Muted
  static const Color ghostText    = Color(0xFF4A5568); // Disabled

  // Surfaces (Nebula Material)
  static const Color nebulaSurface       = Color(0x14FFFFFF); // 8% — panels
  static const Color denseNebulaSurface  = Color(0x1FFFFFFF); // 12% — modals/forms
  static const Color surfaceBorder       = Color(0x18FFFFFF); // 9% border
  static const Color surfaceBorderBright = Color(0x28FFFFFF); // active border

  // Lesson status helper
  static Color lessonStatus(String status) => switch (status.toLowerCase()) {
    'attended'  => successMint,
    'missed'    => errorRose,
    'cancelled' => warningAmber,
    _           => stellarBlue,
  };

  // Gradients
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
}
```

**Color roles:**
- Purple → personal zone, makeup/отработка badge, depth
- Blue → navigation, primary actions, clarity
- Cyan → focus, confirmation, input active state
- Mint → success, attended lessons
- Amber → warning, cancelled, debt, unfilled
- Rose → missed lessons, errors
- Background MUST always have blue-purple color temperature — never `#000000`

### Design Tokens

```dart
abstract class NebulaTokens {
  // Radii
  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 18;
  static const double radiusLG = 24;
  static const double radiusXL = 32;  // ← pill badges

  // Spacing (8px grid)
  static const double sp4  = 4;
  static const double sp8  = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;

  // Blur
  static const double blurLight  = 8;
  static const double blurMedium = 16;
  static const double blurDense  = 28;

  // Glow presets
  static List<BoxShadow> glowSoft(Color c) =>
    [BoxShadow(color: c.withOpacity(0.20), blurRadius: 12, spreadRadius: 0)];
  static List<BoxShadow> glowMedium(Color c) =>
    [BoxShadow(color: c.withOpacity(0.30), blurRadius: 20, spreadRadius: 2)];
  static List<BoxShadow> glowFocus(Color c) =>
    [BoxShadow(color: c.withOpacity(0.45), blurRadius: 28, spreadRadius: 4)];
}
```

### Visual Rules

- Background must always be darker than surfaces: `deepVoid < spaceBlack < nebulaSurface`
- Maximum 2–3 active accent colors per screen
- Glow supports focus but does NOT replace contrast
- Directional light implied from top-left: subtle `LinearGradient` on surfaces going `white.withOpacity(0.08)` top-left → transparent bottom-right
- **Luminous border-edge glow pattern** (from ref images): border color + matching outer BoxShadow with same color — the card edge glows as lit from within

---

## 4. Motion Principles

Motion feels like: drifting through nebula · moving between constellation nodes · shifting focus in layered depth.

```
tap response:       80–160ms    easeOut
focus/hover glow:   120–220ms   easeInOut
success/error:      180–320ms   easeOut
tab transition:     280–450ms   easeInOut (NOT 200ms)
screen transition:  350–650ms   easeInOut
ambient loops:      6–20s+      soft cyclic
```

**Rules:**
- Ambient motion must be subtle — noticeable only when completely still
- Support `MediaQuery.of(context).disableAnimations` reduced motion
- Never run more than 3 simultaneous animated glows
- Tab transitions: 360ms easeInOut (current is 200ms easeOut — too fast)
- `SpaceTransition` (existing page transitions) — already correct, keep as-is

---

## 5. Component System

### NebulaSurface
Replaces `GlassCard`. All panels, cards, content wrappers.
```dart
BackdropFilter(blur: blurMedium) +
Container(
  color: nebulaSurface,          // 0x14FFFFFF — NOT CosmoColors.glass (0x0A = too thin)
  border: surfaceBorder,
  borderRadius: radiusMD/LG,
  boxShadow: glowSoft(accentColor),  // only if semantically meaningful
)
```

### DenseNebulaSurface
For text-heavy content, modals, forms: `denseNebulaSurface (0x1F)` + `blurDense`.

### StellarButton
Replaces `CosmoButton`.
- Scale 1.0→0.96 on press, easeOut 120ms — foundation already correct in CosmoButton
- BoxShadow: `Offset.zero` (radial glow, NOT `Offset(0, 6)` directional shadow)
- Non-disabled: NOT full-opacity solid fill. Use luminous tint: `color.withOpacity(0.15–0.20)` fill + border + radial glow
- Disabled: opacity 0.4, no glow

### OrbitTabBar
Replaces `_KosmoNavBar`.
- Background: `DenseNebulaSurface` + `BackdropFilter` — NOT solid `CosmoColors.dark`
- Active indicator: `AnimatedContainer` 360ms easeInOut (current: 200ms)
- Active: glow `BoxShadow` added (current: missing)
- Border: only top — `Border(top: BorderSide(color: surfaceBorder))`

### PulseIndicator (status dot)
- `attended` → successMint glow, steady
- `missed` → errorRose glow, steady
- `cancelled` → warningAmber, steady
- `scheduled` (unfilled past) → warningAmber, pulsing loop
- `today` → stellarBlue, slow breathing pulse

### MistModal (BottomSheet base)
Replaces all `Container(color: CosmoColors.dark)` in bottom sheets.
- `DenseNebulaSurface` + `BackdropFilter`
- Border: top + sides only, `surfaceBorder`
- Entry: slide + fade from below with spring physics
- Current `_DayLessonsSheet` and `LessonModal` container — both need this treatment

### Pill Status Badge
From ref images (06_component_refs) — pill-shaped, NOT rectangle:
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.18),
    borderRadius: BorderRadius.circular(NebulaTokens.radiusXL),  // 32 — full pill
    border: Border.all(color: statusColor.withOpacity(0.60), width: 1),
  ),
  child: Text(label, style: TextStyle(color: statusColor.withOpacity(0.9), fontSize: 11)),
)
```
Current `_StatusBadge` uses `borderRadius: 8` — not pill-shaped.

### OrbitLoader
Replaces `CircularProgressIndicator`. Rotating arc of light, stellarBlue/auroraCyan, 800ms easeInOut loop.

---

## 6. Flutter Implementation Notes

**Preferred primitives:**
```
Stack / Positioned / Transform                — layering
AnimatedContainer / TweenAnimationBuilder     — implicit animation
AnimationController + CurvedAnimation         — explicit control
BackdropFilter / ImageFiltered                — blur
CustomPainter                                 — stars, lines, glow
ClipRRect / ShaderMask                        — masking
PageRouteBuilder                              — transitions (already done via SpaceTransition)
Hero                                          — shared element
RepaintBoundary                               — REQUIRED around painters
```

**Critical performance rules:**
- Max 1 fullscreen `BackdropFilter` per screen
- `shouldRepaint` must return `false` when data unchanged — **current `_StarFieldPainter` always returns `true`** → critical fix
- `AnimatedStarBackground`: no `RepaintBoundary`, `setState` on every tick → wraps full tree in rebuild
- Star count ≤ 80 with drift velocity ≤ 0.3 (current: 180 stars)
- Background needs fixed seed — spatial memory rule — current uses `Random()` fresh each render

**Architecture target:**
```
lib/core/theme/
  nebula_colors.dart       ← replaces cosmo_colors.dart
  nebula_tokens.dart       ← new: spacing, radii, motion, glow tokens
  app_theme.dart           ← updated ColorScheme + tokens

lib/shared/widgets/
  nebula_surface.dart      ← NebulaSurface + DenseNebulaSurface
  stellar_button.dart      ← replaces cosmo_button.dart
  orbit_tab_bar.dart       ← replaces _KosmoNavBar in app_router.dart
  nebula_background.dart   ← replaces animated_star_background.dart
  mist_modal.dart          ← new: bottom sheet base
  pulse_indicator.dart     ← new: status dot
```

---

## 7. Refactor Priorities

### Phase 1 — Foundation (nothing else works without this)
1. `nebula_colors.dart` — new palette, replaces `cosmo_colors.dart`
2. `nebula_tokens.dart` — all tokens centralized
3. `app_theme.dart` — update `ColorScheme`, fix `bottomNavigationBarTheme` (remove solid bg), fix `elevatedButtonTheme` (remove solid fill)

### Phase 2 — Shared Primitives
4. `nebula_surface.dart` — `NebulaSurface` + `DenseNebulaSurface`
5. `stellar_button.dart` — fix Y-offset glow, luminous fill, use tokens
6. `pulse_indicator.dart` — semantic status dot

### Phase 3 — App Shell
7. `orbit_tab_bar.dart` — blur bg, glow active, 360ms transition
8. `nebula_background.dart` — `RepaintBoundary`, `shouldRepaint: false`, fixed seed, 80 stars
9. `mist_modal.dart` — `DenseNebulaSurface` bottom sheet base

### Phase 4 — Calendar Screen First
10. `calendar_screen.dart` — `NebulaSurface` for GlassCard wrappers, token spacing, pill `_StatChip`
11. `constellation_calendar.dart` — update to new color tokens
12. `lesson_modal.dart` — `MistModal` container, `StellarButton` for `_ActionButton`, pill `_StatusBadge`
13. `_DayLessonsSheet` — `MistModal` container, `PulseIndicator` for status dot

### Phase 5 — Other Screens
14. Students screen — `NebulaSurface` cards (keep gradient avatars exactly)
15. Salary screen — `NebulaSurface` for hero card (keep giant number energy)
16. Login screen — `DenseNebulaSurface` form (keep orbital planet animation exactly)

### Phase 6 — Polish
17. `OrbitLoader` replacing all `CircularProgressIndicator`
18. Reduced motion support
19. Performance audit pass

**Rule:** Never start Phase 2+ before Phase 1 is complete. Never rewrite all screens at once.

---

## 8. Anti-Patterns

### Visual
- Pure `#000000` background — always use `deepVoid #050816` or `spaceBlack #0B1020`
- Full-opacity solid colored buttons — buttons must be luminous tint + glow, not solid fill
- Flat `color.withOpacity(0.1)` chips with radius 8 — should be pill-shaped (radius 32) with border `color.withOpacity(0.60)`
- `BoxShadow(offset: Offset(0, 6))` — directional Material shadow, NOT radial nebula glow
- `CosmoColors.glass = 0x0A` (4%) — too thin to be Nebula Material, upgrade to 8–12%
- Solid `CosmoColors.dark` in bottom sheets — breaks "emerging from nebula depth"
- `bottomNavigationBar: backgroundColor: CosmoColors.dark` — hard edge kills spatial continuity
- Random per-render star positions — background must have spatial memory (fixed seed)

### Performance
- `shouldRepaint: true` always — triggers max repaints every frame
- No `RepaintBoundary` around animated painters
- `setState(() {})` in animation ticker without RepaintBoundary — rebuilds full widget tree
- Multiple fullscreen `BackdropFilter` layers simultaneously

### Design philosophy
- More effects ≠ more Nebula — premium restraint wins
- Glow on every element equally — glow must mark semantically important states only
- Random neon accents without dark context — every bright element needs surrounding depth
- Tab transition at 200ms — too fast, feels abrupt, not spatial

---

## 9. What Already Fits Nebula (Do NOT Change)

| Element | Why |
|---------|-----|
| `ConstellationCalendar` nodes | Days as star nodes + pulse/glow = core Nebula metaphor |
| `SpaceTransition` | Nebula clouds + parallax drift = already correct, keep as-is |
| `CosmoButton` scale press (0.96, easeOut) | Foundation is right — only fix glow offset |
| Space Grotesk + Space Mono fonts | Exactly the Nebula-recommended pair |
| Haptic feedback by severity | Premium tactile detail — keep exactly |
| `statusColor()` lesson mapping | Light-as-language correctly maps states |
| Transparent AppBar, zero elevation | Spatial continuity already present |
| Gradient avatar circles (students) | Premium, distinctive — keep exactly |
| Orbital planet animation (login) | Signature entry moment — keep exactly |
| Salary giant Space Mono numbers | Impactful, distinctive — keep the energy |
| Spring physics on sheet drag | High-quality tactile gesture — keep |
| `SpaceTransition` page transitions | Already Nebula-correct, keep |

---

## 10. Quick Code Reference

### NebulaSurface widget skeleton
```dart
class NebulaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final List<BoxShadow>? glow;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? NebulaTokens.radiusMD;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: dense ? NebulaTokens.blurDense : NebulaTokens.blurMedium,
          sigmaY: dense ? NebulaTokens.blurDense : NebulaTokens.blurMedium,
        ),
        child: Container(
          padding: padding ?? EdgeInsets.all(NebulaTokens.sp20),
          decoration: BoxDecoration(
            color: dense ? NebulaColors.denseNebulaSurface : NebulaColors.nebulaSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: NebulaColors.surfaceBorder, width: 1),
            boxShadow: glow,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### StellarButton radial glow (no Y-offset)
```dart
BoxShadow(
  color: accentColor.withOpacity(pressProgress * 0.45 + 0.20),
  blurRadius: 20 + pressProgress * 8,
  spreadRadius: 0,
  offset: Offset.zero,   // ← radial, not directional
)
```

### OrbitTab active state
```dart
AnimatedContainer(
  duration: NebulaTokens.tabTransition,   // 360ms
  curve: Curves.easeInOut,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
    color: selected ? NebulaColors.nebulaPurple.withOpacity(0.15) : Colors.transparent,
    boxShadow: selected ? NebulaTokens.glowSoft(NebulaColors.stellarBlue) : null,
  ),
)
```

### RepaintBoundary — ALWAYS wrap animated backgrounds
```dart
RepaintBoundary(
  child: NebulaBackground(child: yourContent),
)
```

### Luminous border-edge glow (from reference images)
```dart
decoration: BoxDecoration(
  border: Border.all(color: NebulaColors.stellarBlue.withOpacity(0.45), width: 1),
  boxShadow: [BoxShadow(
    color: NebulaColors.stellarBlue.withOpacity(0.25),
    blurRadius: 12,
    spreadRadius: 0,
    offset: Offset.zero,
  )],
)
// Border color and shadow color must be the SAME accent
```

---

## 11. Pre-Phase Checklist

Before starting any Phase, verify:
- [ ] readability — text is clear on all surfaces
- [ ] consistency — same tokens used throughout
- [ ] performance — no unnecessary repaints
- [ ] premium feel — calm, not loud
- [ ] visual restraint — glow only where semantically meaningful

If a screen feels noisy, gimmicky, or visually exhausting → simplify.

---

## 12. Key Source Files

- Full spec: `/Users/mickrusa4/Desktop/SPACE_MORPHISM/nebula_full_spec/nebula_full_spec.txt`
- Master prompt: `/Users/mickrusa4/Desktop/SPACE_MORPHISM/nebula_full_spec/nebula_master_prompt.md`
- Flutter notes: `/Users/mickrusa4/Desktop/SPACE_MORPHISM/nebula_full_spec/nebula_flutter_notes.md`
- Design brief: `/Users/mickrusa4/Desktop/SPACE_MORPHISM/nebula_reference_pack/nebula_references/09_notes_and_observations/nebula_design_brief.md`
- Reference images: `/Users/mickrusa4/Desktop/SPACE_MORPHISM/refs_prepared/`
- Skill pack: `/Users/mickrusa4/.claude/skills/spacemorphism/`
- Flutter project: `/Users/mickrusa4/Desktop/tg-playroll-bot/mobile/lib/`

---

*Nebula: liquid nebula shaped into interface. Premium. Restrained. Spatial. Alive.*
