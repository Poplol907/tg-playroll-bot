# Cosmo Light Shader Fallback Boundaries

Last updated: 2026-05-09

## Purpose

This document defines the Phase 4 boundary for light-theme shader behavior. It exists to keep Light Shader interaction focused and prevent accidental expansion into Phase 5 composition, login sphere work, or a full fluid simulation rewrite.

## Mode Responsibilities

### Dark Internals

- Uses existing dark backgrounds through `AppBackgroundHost`.
- Dark background interaction may remain ASCII/code-like.
- Do not route dark mode through the light shader layer.

### Light Shader

- Uses `PathFieldBackground` as the persistent light canvas.
- Adds `InteractiveLightShaderBackground` inside the path field.
- Pointer down and meaningful drag create short-lived soft splats.
- Idle state should stay close to clean white/off-white.
- Splat count remains capped and tiny pointer moves are throttled.
- Reduced motion bypasses pointer-driven shader paint.

### Light Lite

- Uses `PathFieldBackground(animated: false)`.
- Does not include `InteractiveLightShaderBackground`.
- Remains static or near-static.
- Serves as the low-load fallback for users/devices where shader interaction is too much.

## Fallback Rules

- If `MediaQuery.disableAnimations` is true, Light Shader must return content without pointer-driven shader listeners.
- If interaction performance becomes expensive, reduce splat count, splat radius, or move threshold before introducing a new renderer.
- Do not stack multiple full-screen animated backgrounds.
- Do not enable the old background experiments as fallbacks unless a later phase explicitly re-evaluates them.
- Prefer a simple `CustomPainter` fallback before porting a full fluid simulation.

## Current Implementation

- `AppBackgroundHost` routes `AppVisualMode.lightShader` to:
  - `PathFieldBackground`
  - `InteractiveLightShaderBackground`
- `AppBackgroundHost` routes `AppVisualMode.lightLite` to:
  - `PathFieldBackground(animated: false)`
- `InteractiveLightShaderBackground` owns pointer splats, decay, budget, and reduced-motion bypass.

## Out Of Scope For Phase 4

- Login sphere or planet redesign.
- Optimus-level desktop composition.
- Full WebGL/fragment-shader fluid simulation parity.
- Removing old background experiment files.
- Broad theme-token migration beyond what the shader layer needs.
