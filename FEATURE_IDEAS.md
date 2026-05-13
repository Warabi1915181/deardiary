# Dear Diary Feature Ideas

## Context

Dear Diary is currently a SwiftUI app with:

- Home tab showing days left to Our Anniversary.
- To-Do tab with categories, active/completed items, persistence, and drag reordering.
- Settings tab with dating start day configuration.

The app direction is a private relationship companion: memories, plans, milestones, and lightweight daily life tracking.

## Recommended Next Features

### 1. Diary / Memory Log

Core feature for the app name. Users can save daily entries, special memories, mood, photos, and short notes.

User value:

- Turns the app from utility into emotional archive.
- Gives Home screen content beyond countdown.
- Creates foundation for timeline, search, and yearly recap.

Possible MVP:

- New Diary tab.
- Add/edit/delete text entries.
- Entry date.
- Optional mood.
- Persist entries locally.

Future expansion:

- Photo attachments.
- Tags.
- Favorite memories.
- Search.
- “On this day” resurfacing.

### 2. Home Dashboard

Upgrade Home from one countdown card into a summary dashboard.

User value:

- Makes Home feel alive.
- Surfaces important app content quickly.
- Gives users reason to open app daily.

Possible cards:

- Days together.
- Days left to anniversary.
- Latest diary entry.
- Next plan.
- Random memory.
- Active to-do count.

Possible MVP:

- Keep existing anniversary card.
- Add days-together card.
- Add latest diary entry card after Diary exists.
- Add to-do summary card using current `ToDoStore`.

### 3. Milestones

Track meaningful dates: first date, first trip, birthdays, monthly anniversaries, yearly anniversaries, custom events.

User value:

- Fits relationship theme.
- Adds more date-based content to Home.
- Complements existing anniversary logic.

Possible MVP:

- Milestone list.
- Title + date + optional note.
- “Upcoming” sort.
- Home card for next milestone.

Future expansion:

- Notifications.
- Recurring milestones.
- Photo/memory links.
- Countdown widgets.

### 4. Shared Couple Bucket List

Extend to-do into relationship goals: restaurants, trips, movies, gifts, activities.

User value:

- Builds on current to-do system.
- More playful than generic task list.
- Encourages planning together.

Possible MVP:

- Add default categories like Dates, Trips, Movies, Food.
- Add optional “idea” type or bucket-list mode.
- Show completed bucket items as memories.

Future expansion:

- Priority.
- Estimated cost.
- Location.
- Completion date/photo.

### 5. Love Notes

Small private notes or messages saved for later.

User value:

- Simple emotional feature.
- Fast to build.
- Good daily engagement through random note.

Possible MVP:

- Add note title/body.
- Favorite notes.
- Random note card on Home.

Future expansion:

- Scheduled reveal.
- Lock screen widget.
- “Open when...” note categories.

### 6. Photo Memories

Attach images to diary entries, milestones, or completed plans.

User value:

- Makes app more personal.
- Strengthens diary/memory identity.

Possible MVP:

- Support one image per diary entry.
- Local photo picker.
- Thumbnail in entry list.

Future expansion:

- Albums.
- Grid view.
- Slideshow.
- Memory collage.

### 7. Calendar / Plans

Create future date plans with date, location, notes, and checklist.

User value:

- Bridges todo list and milestones.
- Helps manage upcoming relationship activities.

Possible MVP:

- Plan title.
- Date/time.
- Optional location and notes.
- Linked to-do items.

Future expansion:

- Calendar view.
- Notifications.
- Map links.
- Convert completed plan into diary entry.

### 8. Stats / Recap

Show simple relationship and app stats.

User value:

- Lightweight delight.
- Good fit for Home.
- Easy reward loop.

Possible stats:

- Days together.
- Memories saved.
- Plans completed.
- To-dos completed.
- Favorite mood.
- Most active month.

Future expansion:

- Monthly recap.
- Yearly recap.
- Shareable image card.

## Suggested Implementation Order

1. Diary / Memory Log MVP
2. Home Dashboard improvements
3. Milestones
4. Calendar / Plans
5. Photo Memories
6. Love Notes
7. Bucket List polish
8. Stats / Recap

Reasoning:

- Diary should come first because it defines the app identity.
- Home Dashboard should follow because it can surface diary, anniversary, and to-do data.
- Milestones and Plans add structured relationship events.
- Photos and stats become more useful after content exists.

## LLM Planning Notes

```yaml
app:
  platform: iOS
  framework: SwiftUI
  current_tabs:
    - Home
    - To-Do
    - Settings
  current_storage:
    - UserDefaults via AppStorage
    - JSON encoded ToDoStore state

feature_backlog:
  - id: diary
    name: Diary / Memory Log
    priority: 1
    type: core
    suggested_tab: Diary
    depends_on: []
    mvp_entities:
      - DiaryEntry
    mvp_fields:
      - id
      - title
      - body
      - entryDate
      - mood
      - createdAt
      - updatedAt

  - id: home_dashboard
    name: Home Dashboard
    priority: 2
    type: enhancement
    suggested_tab: Home
    depends_on:
      - diary
    mvp_cards:
      - anniversary_countdown
      - days_together
      - latest_diary_entry
      - todo_summary

  - id: milestones
    name: Milestones
    priority: 3
    type: feature
    suggested_tab: Home or dedicated Milestones
    depends_on: []
    mvp_entities:
      - Milestone
    mvp_fields:
      - id
      - title
      - date
      - note
      - createdAt

  - id: plans
    name: Calendar / Plans
    priority: 4
    type: feature
    suggested_tab: Plans
    depends_on:
      - todo
    mvp_entities:
      - Plan
    mvp_fields:
      - id
      - title
      - date
      - location
      - notes

  - id: photo_memories
    name: Photo Memories
    priority: 5
    type: enhancement
    depends_on:
      - diary
    mvp_scope:
      - one_image_per_diary_entry
      - local_photo_picker

  - id: love_notes
    name: Love Notes
    priority: 6
    type: feature
    depends_on: []
    mvp_entities:
      - LoveNote
    mvp_fields:
      - id
      - title
      - body
      - isFavorite
      - createdAt

  - id: bucket_list
    name: Shared Couple Bucket List
    priority: 7
    type: enhancement
    depends_on:
      - todo
    mvp_scope:
      - default_relationship_categories
      - completed_items_as_memories

  - id: stats_recap
    name: Stats / Recap
    priority: 8
    type: delight
    depends_on:
      - diary
      - plans
    mvp_metrics:
      - days_together
      - memories_saved
      - plans_completed
      - todos_completed
```

## MVP Recommendation

Build Diary first, then use it to enrich Home.

Small first slice:

1. Add `DiaryEntry` model and local store.
2. Add Diary tab with list and empty state.
3. Add sheet for new entry.
4. Persist entries locally.
5. Add latest diary entry card to Home.

