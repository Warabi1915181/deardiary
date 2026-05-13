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

## Visual Language

### Palette

Use soft, low-contrast colors.

Preferred color families:

- Warm cream
- Blush pink
- Soft rose
- Sage green
- Muted lavender
- Warm brown or deep plum for text

Avoid:

- Pure black for large text areas
- Bright corporate blue
- Harsh red except for tiny heart accents
- Heavy gray UI

Current app tokens already point in a good direction:

- `Backdrop`
- `PrimaryBackground`
- `SecondaryBackground`
- `PrimaryForeground`
- `SecondaryForeground`
- `SageBackground`
- `SageForeground`
- `Muted`

Future styling should reuse and refine these tokens instead of adding many one-off colors.

### Cards

Cards should feel like paper notes or diary pages.

Recommended traits:

- Rounded corners: `16`, `20`, or `24`
- Soft shadows
- Warm off-white fills
- Comfortable padding
- Gentle spacing
- No hard borders unless needed as a 1px divider

Use cards for:

- Home summaries
- Diary entries
- Upcoming plans
- Memory previews
- Milestones

### Typography

Current typography fits the app well:

- `PlayfairDisplay` for elegant titles and readable body text.
- `DancingScript` for emotional accents, large numbers, and special dates.

Guidance:

- Use script font sparingly.
- Keep body text readable.
- Use large romantic titles on emotional screens.
- Use smaller, calmer labels for metadata.

Examples:

- Big title: `Our Anniversary`
- Script accent: `423`
- Metadata: `May 13, 2026`
- Body: diary entry text

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

Guidance:

- Maintain enough contrast, especially in dark mode.
- Do not rely on color alone for meaning.
- Keep touch targets comfortable.
- Avoid tiny script text for important content.
- Support dynamic type where practical.

## Implementation Guidance

When adding new UI:

1. Reuse existing color assets first.
2. Reuse `Card` or evolve it into a shared app card style.
3. Keep all spacing in multiples of 4.
4. Prefer soft cards over dense lists for emotional content.
5. Use lists/forms mainly for settings and structured editing.
6. Keep Home curated, not exhaustive.

When choosing between two designs:

- Pick warmer over colder.
- Pick simpler over denser.
- Pick memory-focused over task-focused.
- Pick readable over decorative.

