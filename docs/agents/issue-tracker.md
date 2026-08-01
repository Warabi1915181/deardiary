# Issue tracker: Linear

Issues and PRDs for this repo live in **Linear**, workspace **Mochiholic**, team **Dev**
(key **DEV**, so identifiers read `DEV-<n>`). GitHub Issues on
`Warabi1915181/deardiary` are **not** used — ignore them.

## What lives where

Specs, plans and the feature backlog live in Linear, in the **Dear Diary** project —
not in this repo. There is no `FEATURE_IDEAS.md`; it was migrated to Linear on
2026-08-01. Before proposing or starting a feature, read that project's issues rather
than looking for a plan document in the tree.

What stays in the repo, and remains authoritative:

- `ARCHITECTURE.md` — sync design
- `DESIGN.md` — visual direction
- `CONTEXT.md` — domain vocabulary
- `docs/adr/` — architectural decisions
- `docs/agents/` — these conventions

All operations go through the project-scoped Linear MCP tools
(`mcp__linear-mochiholic__*`). `mcp__claude_ai_Linear__*` is a different workspace (the
user's work Linear) — never create Dear Diary issues there. Do not shell out to
`gh issue`. If the `linear-mochiholic` tools are not connected in the current session,
say so and stop rather than falling back to GitHub.

## Conventions

Always scope calls to `team: "DEV"`.

- **Create an issue**: `save_issue` with `team: "DEV"`, `title`, `description` (markdown body).
- **Update an issue**: `save_issue` with the existing `id` plus the fields to change
  (`state`, `labels`, `assignee`, `parentId`, ...).
- **Read an issue**: `get_issue` by id or identifier (e.g. `DEV-42`). Use `list_comments`
  for the discussion.
- **List issues**: `list_issues` with `team: "DEV"` and filters (`state`, `label`,
  `assignee`, `query`, `updatedAt`).
- **Comment**: `save_comment` with `issueId` and `body`.
- **Labels / states**: discover the real vocabulary with `list_issue_labels` and
  `list_issue_statuses` for team `DEV` before writing — never invent a label or a state
  name, and never create a duplicate of one that already exists under another spelling.
- **Close**: `save_issue` with a terminal state — `Done`, or `Canceled` for wontfix
  (`Duplicate` also exists) — plus a comment explaining why.

The team's states are `Backlog`, `Todo`, `In Progress`, `Done`, `Canceled`, `Duplicate`;
its labels are `Bug`, `Feature`, `Improvement`. Re-check with the discovery calls above
rather than trusting this snapshot.

## Pull requests as a request surface

**PRs as a request surface: no.** _(Set to `yes` if this repo starts treating external
PRs as feature requests.)_ This is a solo project worked directly on `main` — there are
no PRs to triage.

## When a skill says "publish to the issue tracker"

Create a Linear issue in team `DEV` via `save_issue`.

## When a skill says "fetch the relevant ticket"

`get_issue` on the identifier (`DEV-<n>`), then `list_comments` for the thread.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a parent issue; **tickets** are its sub-issues.

The `wayfinder:*` labels do not exist yet — create them once, on first use, via
`create_issue_label`.

- **Map**: an issue in team `DEV` labelled `wayfinder:map`, holding the Notes /
  Decisions-so-far / Fog body.
- **Child ticket**: an issue created with `parentId` set to the map's id, labelled
  `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`). Once claimed,
  assign it to the driving dev.
- **Blocking**: Linear's native issue relations — set a `blocked by` relation from the
  child to its blocker. Where the relation isn't expressible through the available
  tools, fall back to a `Blocked by: DEV-<n>, DEV-<n>` line at the top of the child's
  description. A ticket is unblocked when every blocker is in a terminal state.
- **Frontier query**: `list_issues` for the map's unfinished children, drop any with an
  open blocker or an assignee; first in map order wins.
- **Claim**: `save_issue` setting `assignee` to the current user — the session's first
  write.
- **Resolve**: `save_comment` with the answer, move the issue to `Done`, then append a
  context pointer to the map's Decisions-so-far.
