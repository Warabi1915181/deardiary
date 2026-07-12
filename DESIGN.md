# Dear Diary Design Direction

## North Star

Dear Diary should feel like a soft private place for two people.

The app is not mainly a productivity tool. It is a relationship companion: part diary, part memory box, part gentle planner.

Design principle:

> Memory first, utility second.

Tasks, plans, and settings should feel useful, but never cold or corporate. The emotional core is the couple's shared life.

## Core Feeling

The app should feel:

- Warm
- Private
- Romantic
- Calm
- Personal
- Safe
- Lightly handmade

It should not feel:

- Corporate
- Dense
- Harsh
- Overly gamified
- Like a generic task manager

Good mental model:

> A tiny shared scrapbook that also helps us remember plans.

"Private" has a precise visual meaning here: **enclosure**. The app should feel like being inside a small warm-lit room with the door closed and the world outside. In the dark scene this is expressed through genuine, cozy dimness — dimness is a feature, not a rendering compromise.

## Two Scenes, One Home

The app has two complete emotional renderings, called **scenes**. A scene is a mood with its own palette — not a brightness setting, and never one scene dimmed or inverted into the other.

- **Morning** (light): a soft morning scrapbook. Warm cream, blush pink, soft rose.
- **Candlelight** (dark): a genuinely dark, warm-lit private room. Deep warm darkness, candle-flame accents.

What unifies them is the **warmth bridge**: every color in both scenes is warm-tinted. No neutral gray, no pure black, no cool tint anywhere — plus identical typography, card language, spacing, and voice.

### Why Candlelight has its own accent

Pink at full saturation vibrates on dark surfaces and fails the candlelit mood. A desaturated dusty rose would be technically workable (standard dark-mode practice), but it tells a weaker story than an ember accent that belongs to the night. Hue-swapping an accent between modes is rare for consumer brands because of brand-recognition concerns; those concerns don't apply to a private app for two people, and reading apps set precedent for warm, scene-framed night palettes. So Candlelight commits to ember.

### Candlelight atmosphere

Candlelight is a tiered whole-app environment, not an effect reserved for a few screens. Its atmosphere follows emotional purpose: strongest around shared memories, quiet around planning, and still around focused utility such as settings, editors, forms, and sheets.

The light comes from an **Implied Flame** beyond the lower screen edge. Never place a literal candle or flame ornament inside the interface. Any embers belong to the room behind the content: keep them rare, fixed independently of scrolling, and restricted to open margins and gaps. They must never cross text, controls, photos, or card interiors.

On Home, Latest Memory receives the strongest warm catch-light because it is both closest to the Implied Flame and aligned with the product's memory-first principle. The Anniversary card receives softer reflected light. When no memory exists, Anniversary temporarily becomes the focal surface.

The Diary list uses one screen-fixed room atmosphere. Memory cards do not own independent flicker or glow; they remain stable while scrolling through the atmosphere. Favorite hearts may retain their small jewel glow. Stronger local illumination belongs only in memory detail.

In memory detail, preserve Photo Fidelity: illuminate the backdrop or frame around a photo, never the image pixels. Do not apply warmth, flicker, vignette, distortion, or other scene treatment directly to personal photos. A photo may appear to cast subtle reflected warmth onto its surrounding surface. Text remains stable.

Our List receives only a faint, fixed lower-edge light. It has no embers, row or card flicker, or candle reaction on completion. Completion remains a stable Sage interaction so planning feedback does not become gamified or blur the meaning of Ember and Sage.

The Implied Flame's lower glow may extend beneath the system tab bar so navigation naturally reflects the room's warmth. Do not attach shaders, flicker, embers, or custom glow to tab controls or selection states.

Utility flows use a strict atmosphere cutoff. The Settings root may retain a faint static lower warm gradient; Settings details use the static Backdrop alone. Editors, forms, sheets, confirmation dialogs, sync or error banners, and keyboard-visible states have no shader-driven motion or atmospheric glow beyond their semantic scene colors.

When Reduce Motion is enabled, Candlelight becomes still: preserve its static warm light, palette, vignette, enclosure, and heart shadow, but remove flicker, embers, gradient drift, breathing glow, heat shimmer, and animated noise. Functional state feedback may use restrained reduced-motion alternatives; only decorative atmospheric movement has a hard cutoff.

Flicker belongs only to the Implied Flame's lower light field, never to a full-screen color treatment. Keep the Backdrop, text, photos, navigation, and card surfaces stable; only nearby card edges may catch tiny reflected variation, with almost no visible change at the top of the screen.

Do not use heat shimmer or refractive distortion. Without a visible flame there is no believable placement for it, and warping lower-edge content or navigation would resemble a rendering defect.

Use a static vignette to reinforce enclosure: subtle darkening at upper corners and side edges on Home and Diary, much fainter on Our List and the Settings root, and none in details, forms, or sheets. Never animate it or darken the central reading region. The lower edge remains warm from the Implied Flame.

Prototype Candlelight atmosphere on Home first. It must prove the Implied Flame, Latest Memory catch-light, Anniversary reflection, vignette, negative-space embers, tab-bar under-light, no-memory fallback, and Reduce Motion state before the treatment expands to Diary and then the quieter Our List and Settings variants.

Home atmosphere sits behind readable content in this order: stable Backdrop, lower animated light field, sparse embers, static vignette, then normal content. Only Latest Memory opts into a tiny outer edge catch-light; its fill, photo, and text remain stable. The system tab bar stays above all atmospheric layers.

Candlelight atmosphere follows the same system appearance that selects the scene colors; this experiment adds no separate scene setting. Switching into Candlelight gently reveals the atmosphere without a particle burst or timeline restart. Switching to Morning removes it. Under Reduce Motion, Candlelight enters its still state immediately.

Perpetual ambience never outranks device health or responsiveness. Stop atmospheric timelines while inactive or backgrounded. In Low Power Mode, use the still light and remove flicker and embers. If performance degrades, remove embers first and then freeze the light; resuming must be smooth, without simulation catch-up or particle bursts.

Treat the evening reference as mood direction, not a literal intensity target. Atmosphere should become apparent only after a second look: usually zero to two visible embers, no whole-screen orange haze, no neon card outlines, and only a barely stronger edge on Latest Memory. A frozen screenshot must still read clearly as Candlelight without effects carrying the scene identity.

Candlelight atmosphere is passive. It does not follow touch, react to scrolling, use gyroscope or parallax input, burst on taps, attract to drags, or couple to haptics. Content interactions remain direct and predictable while the room changes slowly on its own.

## Visual Language

### Color Roles

Colors are defined as **semantic roles**. Each role has one meaning and two renderings — one per scene. Do not add one-off colors; extend the roles.

| Role | Meaning | Morning rendering | Candlelight rendering |
|---|---|---|---|
| **Backdrop** | The room — outermost screen background | Warm cream | Deep warm dark (never pure black, never gray) |
| **Surface** | The paper — cards, sheets, popovers | Warm off-white | Warm dark, a step lighter than Backdrop |
| **Surface Muted** | Recessed wells — placeholders, control tracks, inset panels | Warm near-white | Warm dark, a step darker than Surface |
| **Ink** | Neutral text (headings, labels without emotional weight) | Warm brown / deep plum | Warm off-white |
| **Ink Muted** | Metadata, quiet labels | Softened warm brown | Softened warm cream |
| **Romance Accent** | Emotional emphasis: buttons, highlights, fills | Deep rose text/icons over blush fills | **Ember** — candle-flame / sunset orange |
| **Heart Rose** | The heart glyph only | Bright rose | Muted dusty rose |
| **Sage** | Done, growth | Sage green | Olive-shifted, desaturated sage |
| **Plum** | Secondary flavor | Muted lavender | Plum-shifted, desaturated lavender |

Rules:

- **Warmth bridge.** No neutral color anywhere, in either scene. Every gray is actually a warm brown; every dark is candlelit, not charcoal.
- **One accent per scene.** Romance Accent renders rose by Morning, ember by Candlelight. Pink does not appear in Candlelight — with one exception:
- **Heart Rose is glyph-only.** In Candlelight, the muted dusty rose applies to the heart symbol itself (`heart`, `heart.fill`) wherever it appears, and to nothing else. A button *containing* a heart is still ember. Rose at night is a rare jewel.
- **Ember is night-only.** It never leaks into Morning. Morning stays pure cream/blush/rose.
- **Candlelight colors are desaturated.** Saturated colors vibrate on dark surfaces. Every Candlelight rendering is softened relative to its Morning counterpart.
- **Emotional text wears the accent.** Diary/memory titles and body text render in Romance Accent (rose by Morning, ember by Candlelight) — a deliberate choice; Ink is for neutral text. Accent body text must still meet the AA floor.

Avoid:

- Pure black anywhere (causes halation, kills warmth)
- Neutral or cool grays
- Bright corporate blue
- Harsh red except for tiny heart accents
- Saturated fills on dark surfaces

Exact color values are decided in dedicated design sessions, not in this document.

#### Migration notes

Candlelight draft values are in place for all tokens (first iteration — values still being tuned in design sessions). `Surface` and `HeartRose` exist as assets; `Card` fills with `Surface`; the tab view tints with the Romance Accent explicitly.

Asset names now match the role vocabulary (`RomanceForeground`/`RomanceBackground`, `PlumForeground`/`PlumBackground`, `SurfaceMuted`, `Surface`, `HeartRose`, `Backdrop`, Sage pair). `AccentColor` keeps its build-mandated name and mirrors `RomanceForeground`.

Remaining:

- Morning's Sage renderings are brighter than "sage" implies; revisit when tuning Morning.
- System-styled controls must be checked in both scenes whenever one is added; SwiftUI's default accent fallback is corporate blue (a violation) — tint explicitly with roles.

### Cards

Cards should feel like paper notes or diary pages.

Recommended traits:

- Rounded corners: `16`, `20`, or `24`
- Comfortable padding
- Gentle spacing
- No hard borders unless needed as a 1px divider
- Fill is always the Surface role — never a hardcoded color

Depth per scene:

- **Morning**: warm off-white fills with soft shadows, like paper on a desk.
- **Candlelight**: elevation is expressed by *lightness*, not shadow. Cards are a step lighter than the Backdrop, as if the paper catches the candle's glow; higher layers (sheets, popovers) are lighter still. Shadows retire at night — they are invisible on dark ground.

Use cards for:

- Home summaries
- Diary entries
- Upcoming plans
- Memory previews
- Milestones

### Typography

The app is **handwritten on paper** (adopted 2026-07 from the scrapbook reference direction). Three hands, each with one job:

- `PatrickHand` — neat everyday handwriting. Body text, labels, metadata. The app-wide default font.
- `Caveat` — a quicker, looser hand. Titles, page headers, emphasis.
- `DancingScript` — flourish. Big numbers and rare script accents only.

`PlayfairDisplay` is retired from the UI (files kept in repo for now).

Guidance:

- All UI text is handwritten; SF appears only where a view explicitly opts into `.system` (and in system chrome like the tab bar).
- Caveat draws small for its point size; the font roles in `Font_Extension.swift` scale it up (~1.2×) so call sites keep familiar point sizes. Go through the roles, never `Font.custom` directly.
- Patrick Hand has a single weight — create emphasis with size, color, or a switch to Caveat, not with `fontWeight`.
- Keep body text readable: Patrick Hand at 14+ only; never DancingScript for body or important metadata.
- Use large handwritten titles on emotional screens; smaller, calmer labels for metadata.

Examples:

- Page title / card title: Caveat (`Our Anniversary`, `Beach sunset walk`)
- Script accent: DancingScript (`423`)
- Metadata: Patrick Hand (`May 13, 2026`)
- Body: Patrick Hand (diary entry text)

### Handmade cues

The scrapbook feel comes from a few physical cues, used with restraint:

- **Taped photos.** Photos sit in a `TapedPhoto` frame: thin paper border, ~1° of rotation, one strip of `WashiTape` on the top edge. Like a snapshot taped into the book.
- **Warm shadows.** Shadows are warm brown, never neutral black — paper on a wooden desk, not a floating UI panel.
- **One cue per card, at most.** Tape, rotation, and doodles are seasoning. A card earns a cue when it holds a memory; utility cards (settings, sync, forms) get none.

By Candlelight the cues are rendered in light, not shade (adopted 2026-07 from the evening reference):

- **Glow replaces shadow.** Cards lose their drop shadow and gain a faint ember rim on the top edge — the paper catching the flame. The rim is a whisper (~0.2 opacity), never a neon outline.
- **Tape catches the light.** Washi tape renders as translucent ember, softly lit, instead of blush paper.
- **The heart glows.** The Heart Rose glyph carries a small rose glow at night — the one jewel in the dark room.
- Same restraint rule: glow is the night rendering of an existing cue, never a new layer of decoration. No string lights, no fireflies, no glowing borders on utility surfaces.

Rejected from the reference mock (they violate "not overly cute" / readability):

- Mascots and character stickers
- Scattered sparkle/heart confetti as screen decoration
- Emoji inside body copy by default
- Decorating utility screens

### Icons

Use SF Symbols softly.

Good symbols:

- `heart`
- `heart.fill`
- `sparkles`
- `calendar`
- `leaf`
- `bookmark`
- `photo`
- `book.closed`
- `pencil`
- `checkmark.circle`

Guidance:

- Prefer simple symbols.
- Avoid too many filled icons.
- Use accent color sparingly.
- Icons support text; they should not dominate.
- In Candlelight, accented icons render ember like everything else — except the heart glyph, which is Heart Rose.

## Product Voice

Copy should sound intimate, simple, and human.

Use:

- “Our Anniversary”
- “Days together”
- “A little memory”
- “Something to look forward to”
- “Write today down”
- “No memories yet”
- “Done together”

Avoid:

- “Task management”
- “Productivity”
- “Dashboard”
- “Records”
- “Data”
- “Item created successfully”

Tone should be calm and affectionate, not overly cute.

## Screen Direction

### Home

Home should answer:

> What matters to us today?

It should feel like an emotional summary, not a control panel.

Possible layout:

1. Gentle greeting
2. Hero anniversary or days-together card
3. Latest diary entry or random memory
4. Next plan or bucket list idea
5. Small stats row

Possible Home cards:

- Days together
- Days left to anniversary
- Latest diary entry
- Random memory
- Next plan
- Active to-do count
- Completed together count

Home should stay sparse. Do not fill it with every metric.

### Diary

Diary should feel like opening pages.

Recommended traits:

- Entry list as stacked paper cards
- Date labels
- Optional mood pill
- Optional photo thumbnail later
- Gentle empty state

Empty state copy:

> No memories yet. Start with today.

New entry flow should be uncluttered:

- Title
- Date
- Mood
- Body
- Optional photo later

Future feature:

- “On this day” resurfacing old entries.

### To-Do / Bucket List

Current To-Do should gradually feel more relationship-specific.

Possible wording:

- “To-Do” for current tab
- “Things to do together” for future bucket list
- “Done together” for completed items

Good default categories:

- Dates
- Trips
- Food
- Movies
- Gifts
- Home

Long-term direction:

- Keep general to-dos useful.
- Add relationship flavor through categories, copy, and Home summaries.
- Completed plans can become memories.

### Plans

Plans should bridge tasks and memories.

Plan fields:

- Title
- Date
- Location
- Notes
- Linked to-dos

Visual direction:

- Calendar-style date badge
- Soft card layout
- “Something to look forward to” framing

Future flow:

> Plan created → to-dos completed → plan done → diary memory created.

### Settings

Settings should stay simple and quiet.

Guidance:

- Keep Settings practical.
- Avoid decorative overload.
- Use standard controls when they improve clarity.
- Keep naming human: “Dating Start Day”, “Appearance”, “Notifications”.

## Navigation

Keep tab count low.

Recommended future tab set:

- Home
- Diary
- Plans
- Settings

Current To-Do can either remain a tab or later merge into Plans.

Avoid more than five tabs. Too many tabs make the app feel busy.

## Motion

Motion should be soft and subtle.

Good motion:

- Cards fade in
- Cards slide slightly upward
- Saving closes sheets gently
- Random memory crossfades
- Completing a task has a short satisfying delay

Avoid:

- Large bouncy animations
- Confetti as default behavior
- Fast or flashy transitions
- Motion that competes with reading

## Layout Rules

Use spacing and sizing in multiples of 4 by default.

Good values:

- `8`
- `12`
- `16`
- `20`
- `24`
- `32`

Use 1px only for true dividers or hairlines.

General spacing:

- Screen horizontal padding: `16`
- Card padding: `16` or `24`
- Section spacing: `16` or `24`
- Row spacing: `8` or `12`

## Accessibility

Design should stay readable and usable.

Hard rule:

- **Text meets WCAG AA in both scenes**: body text at least 4.5:1 against its surface, large text at least 3:1. "Soft, low-contrast" applies to surfaces and decoration — never to text against its surface.

Both scenes were audited against this rule (2026-07): every text/surface token combination passes. Softness lives in the pastel fills; text renderings are deep enough to read. Re-run the audit when any token value changes.

Guidance:

- Do not rely on color alone for meaning.
- Keep touch targets comfortable.
- Avoid tiny script text for important content.
- Support dynamic type where practical.

## Implementation Guidance

When adding new UI:

1. Use color roles, never one-off colors. Every color must be one of the roles in this document, with a rendering per scene.
2. Reuse `Card` or evolve it into a shared app card style; its fill is the Surface role.
3. Keep all spacing in multiples of 4.
4. Prefer soft cards over dense lists for emotional content.
5. Use lists/forms mainly for settings and structured editing.
6. Keep Home curated, not exhaustive.
7. Check every new screen in both scenes. Candlelight is a first-class scene, not an afterthought.

When choosing between two designs:

- Pick warmer over colder.
- Pick simpler over denser.
- Pick memory-focused over task-focused.
- Pick readable over decorative.
