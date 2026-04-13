# App Icon Design — MeetClock

**Date:** 2026-04-06  
**Status:** Approved

## Concept

A single banknote on fire. Tone: urgency and pressure — time is money, and it's burning. Not playful, not abstract. The image should land in one glance.

## Background

- Shape: iOS superellipse (standard rounded square)
- Fill: radial gradient, center `#1A1210` → edges `#0D0908`
- Not pure black — the red undertone reads as residual heat

## The Banknote

- Centered, rotated ~8° clockwise
- Width: ~60% of icon canvas
- Style: clean vector illustration, not photo-realistic
- Color: desaturated olive-green `#4A5240` body
- Structure: thin dark border, face area
- Bottom ~60%: intact, legible
- Top ~40%: curls, chars, dissolves into flame. One corner lifts slightly — heat just taking hold
- **Clock easter egg**: in the portrait area, replace the face with a small analog clock face
  - Cream/white circle, minimal stroke hands
  - Hands set to ~10:10 (classic "happy watch" position; reads as time running out in context)
  - Visible at 1024px; not load-bearing at small sizes

## The Flame

Three-layer structure, organic asymmetric shape (2–3 tongues, not a symmetric cartoon):

| Layer | Color | Notes |
|-------|-------|-------|
| Outer | `#C0390B` (deep burnt red) | Wide, soft-edged |
| Mid | `#E8621A` (ember orange) | Narrower |
| Inner core | `#F5A623` → `#FFF0A0` | Amber to near-white at tip |

- Height: flame extends to ~15% from top edge of icon — breathes without touching border
- **Embers**: 4–6 particle dots, color `#F5A623`, opacity 40–80%, scattered above and beside flame, drifting upward-right

## Platform Variants

The icon set already has slots for three iOS variants (`Contents.json`):

| Variant | Treatment |
|---------|-----------|
| **Light** (default) | As specified above |
| **Dark** | Background deepens to `#080504`; flame colors unchanged; bill slightly more desaturated |
| **Tinted** | Trust the structure (T-A). Distinct layered shapes — bill body, flame tongues, embers — separate cleanly under system tint without dedicated artwork. No bespoke tinted asset needed unless testing reveals luminosity merge between bill and flame. |

macOS sizes (16×16 through 1024×1024) use the light variant. At 16×16 only the flame silhouette and bill shape will be legible — the clock easter egg disappears entirely, which is acceptable.

## Production Notes

- Build in vector (Figma, Sketch, or Illustrator) at 1024×1024; export at all required sizes
- Use `export as` rasterization, not live SVG — Xcode expects PNG in the asset catalog
- Test all three iOS variants on device in Settings → Accessibility → Display & Text Size → Color Filters to simulate tinted behavior
- The `AccentColor.colorset` is currently empty — consider setting it to `#E8621A` (the mid-flame orange) for consistent tint across the app
