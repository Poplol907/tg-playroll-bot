# Design

Визуальная система Cosmo Studio (кодовое имя — Nebula / SpaceMorphism).
Источник правды — токены в `mobile/lib/core/theme/`; этот файл — карта для
дизайн-инструментов и агентов. Все значения ниже СУЩЕСТВУЮТ в коде; ничего не
выдумывать, новые значения добавлять сначала в токены.

## Theme

Dark-first. Тёмная тема (`darkInternals`) — эталон бренда: глубокий сине-
фиолетовый «void», живой ascii-water фон, мягкое свечение. Светлая
(`lightLite`) — полноценный режим: матовое стекло на светлом градиенте
«тёплый верх → холодный низ», угловые световые пятна. Обе темы обязаны
читаться одинаково хорошо (архитектурное правило).

## Colors

Токены: `nebula_colors.dart` (палитра), `cosmo_theme_tokens.dart`
(семантические роли на тему), `nebula_alpha.dart` (10 семантических тиров
прозрачности: whisper .04 → opaque 1.0 — сырые альфы запрещены ratchet-тестом).

- Фоны (dark): deepVoid `#050816` → spaceBlack `#0B1020` → depthMid `#141A33`
  → depthNear `#1D2450`. Никогда чистый `#000`.
- Акценты: nebulaPurple `#6F4CFF`, stellarBlue `#3BA7FF` (primary),
  auroraCyan `#6CF7FF` (focus), plasmaPink/cosmicRose (креатив, редко).
- Семантика статусов уроков: successMint `#73FFC7` (проведён), errorRose
  `#FF6B8F` (пропуск), warningAmber `#FFB347` (отмена/долг/view-as).
- Идентичность педагогов: детерминированная палитра `teacherColor(id)` из 5
  статус-нейтральных цветов (без mint/amber — цвет педагога не должен
  читаться как статус).
- Правила: 2–3 активных акцента на экран; свечение поддерживает контраст, не
  заменяет его.

## Typography

`nebula_typography.dart` — ThemeExtension, 12 ролей: displayL 28 / displayM 24
/ titleL 20 / titleM 18 / titleS 15 / bodyL 15 / bodyM 14 / bodyS 13 / labelM
12 / labelS 11 / overline 10 caps / mono 12.

- Семьи: **Space Grotesk** (всё) + **Space Mono** (время, числа, ascii-текстуры).
- Все роли несут `leadingDistribution: even` — оптическая центровка в чипах.
- Сырые `fontSize:` в фичах запрещены ratchet-тестом (baseline 25, только вниз).

## Components

Канонические примитивы в `mobile/lib/shared/widgets/` — новые экраны обязаны
собираться из них:

- **NebulaSurface** — базовая поверхность (профили card/panel/modal/input/
  nav/status в `nebula_surface_profile.dart`): fill + border + specular edge +
  sheen-градиент (объём) + опциональный accent-glow.
- **StellarButton** — primary-кнопка: полупрозрачный акцентный fill,
  радиальное свечение, scale 0.96 press (120ms in / 200ms out), радиус
  control. **NebulaTextButton** — вторичная/компактная.
- **Радиусы** — только роли `NebulaRadii`: pill 999 / hero 32 / panel·modal·
  sheet·nav 24 / card 18 / control 12 / compactControl 8 / micro 4. Шкала:
  шиты 24 → карточки 18 → контролы 12. Сырые цифры запрещены тестом.
- **Модальность** — `showFrostedSheet` / `showFrostedDialog` (root-навигатор,
  blur-барьер растёт с анимацией роута, RepaintPulse на закрытии). Прямой
  showModalBottomSheet запрещён тестом. Обёртки: MistModal, AdaptiveModal,
  NebulaModalSurface.
- **Ошибки** — единая система: AppAsyncView (загрузка/ошибка/данные),
  AppErrorCard / AppInlineErrorCard (+`Повторить`), SheetErrorBanner (строго
  над submit-кнопкой формы), AppEmptyState. Тосты — showNebulaSnackBar:
  top-anchored root-overlay под Dynamic Island, одна высота на всех экранах.
- **Прочее** — OrbitLoader (лоадер), PulseIndicator (статус-точки),
  NebulaDrumPicker (барабан выбора, тема-aware), NebulaSegmentedControl,
  NebulaInput, GlowMenuBar (нижняя навигация), ScrollEdgeFade (мягкое
  растворение краёв всех скроллов — PRIME RULE).

## Layout

- Сетка отступов 8px (`NebulaTokens.sp4…sp48`).
- Safe-зоны: единственный владелец верхнего инсета — AppShell;
  `SafeArea(top:false)` разрешён только 6 shell-экранам (архитектурный тест).
  Экранные отступы — только через `AppSafeInsets`.
- Вкладки — таблица `AppTab` в `app_router.dart` (роут+иконка+подпись+glow);
  индекс, нав-бар и сайдбар выводятся из неё.

## Motion

Токены длительностей: tapFast 120 / tapRelease 200 / feedback 220 /
tabTransition 360 / screenTransition 520 / ambientLoop 12s.

- Кривые: enter/press — easeOut(-Cubic); движение по экрану — easeInOut;
  ambient — мягкий синус.
- Принципы (Emil Kowalski): анимации прерываемы; частые действия не
  анимируются; exit быстрее enter; происхождение анимации — место действия;
  никогда scale от 0.
- `MediaQuery.disableAnimations` обязателен для каждой новой анимации
  (fade-only или jump-вариант).
- Не более 3 одновременных анимированных свечений; фоны в RepaintBoundary,
  спят в покое (пробуждение — RepaintPulse).
