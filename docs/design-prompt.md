# Claude Design prompt block

Paste-ready design-language block for exploring visual variants at
[claude.ai/design](https://claude.ai/design). Values extracted from
`Assets.xcassets` and `Font_Extension.swift`; rules distilled from `DESIGN.md`.
For inspiration only — winning ideas get translated back to SwiftUI against the
real semantic roles.

## Workflow

1. Open claude.ai/design → new project.
2. Paste the block below plus what you want, e.g. *"Home dashboard for this
   app, 3 different layout variants, both scenes."*
3. Optionally upload `.reference/morning.png` and `.reference/evening.png` so
   the agent riffs off the real app instead of guessing.
4. Iterate: "variant 2 but warmer", "try a timeline layout", etc.

Prompt patterns that get good variants:

- **Divergence:** "3 structurally different takes" — not "make it nice".
- **Constraint flip:** "same screen, but entries as stacked polaroids / as
  timeline / as calendar".
- **Scene stress:** "show Candlelight first" — forces a real dark design
  instead of dimmed Morning.

## The block

```text
Design language: "Dear Diary" — a private diary app for a couple. Handmade,
warm, scrapbook-like. Never corporate, never sleek/minimal-gray.

TWO SCENES (not light/dark modes — distinct moods):
- Morning: a soft morning scrapbook. Warm cream, blush pink, soft rose.
- Candlelight: genuinely dark but candle-warm. Ember accent. NOT dimmed Morning.

SEMANTIC COLOR ROLES (Morning / Candlelight):
- Backdrop        #FFF7F5 / #211714   (page background)
- Surface         #FFFDFA / #2E221C   (cards)
- Surface Muted   #FFFDFD / #2A1F1A   (secondary cards, wells)
- Ink             ~#3D2E26 / ~#F2E6D8 (neutral text; warm near-black / warm off-white — approximate)
- Ink Muted       #7A6157 / #CCB8A3   (metadata, quiet labels)
- Romance Accent  #9E3B50 / #EC9A62   (rose by Morning, EMBER by Candlelight — hue swaps by scene)
- Romance Bg      #FFD6DD / #3C2A1D   (accent chip/tint backgrounds)
- Heart Rose      #FF566E / #D18E9B   (heart glyphs ONLY)
- Sage fg/bg      #137A13 on #D7F1E6 / #C3CC9E on #2D2C1E  (success, nature, todo-done)
- Plum fg/bg      #6A52B6 on #EDE7FF / #C9AFC4 on #342334   (secondary emotional tint)
- Warm Shadow     rgba(115,77,64,α) Morning only; Candlelight has no shadows (dark already)

HARD RULES:
- Warmth bridge: NO neutral gray, NO pure black or pure white, NO cool/blue tint,
  in either scene.
- One accent per scene: pink never appears in Candlelight; ember is night-only.
- Emotional text (diary titles, memory body) wears Romance Accent; Ink is for
  neutral text only.
- 4pt grid: all spacing, sizing, corner radii, touch targets are multiples of 4.
  Only exception: 1px hairline dividers.

TYPOGRAPHY (all Google Fonts, handwritten "drawn on paper"):
- Patrick Hand — body, labels, metadata
- Caveat — titles and emphasis (render ~1.2× nominal size; it draws small)
- Dancing Script — flourish: big numbers, rare script accents
Type scale (pt): metadata 14 · body 16 · lead 18 · section header 20 ·
card title 20 (Caveat Bold) · entry title 24 (Caveat Bold) ·
detail title 40 (Caveat Medium) · display number 40 (Dancing Script) ·
screen title 48 (Caveat Medium)

CONTEXT: mobile app, iPhone-sized screens. Features: shared diary entries,
to-dos, home dashboard, settings. Show every design in BOTH scenes.
```

## Keeping it fresh

Colors live in `Dear Diary/Assets.xcassets/*.colorset/Contents.json`; type
scale in `Dear Diary/Font_Extension.swift`. If either changes, re-extract —
this block is a snapshot, not a source of truth.
