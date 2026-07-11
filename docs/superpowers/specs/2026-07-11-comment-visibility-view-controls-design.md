# Comment visibility + view-controls consolidation — Design

> Governing context: the `comment-ui-conventions` memory (binding) and the candidate-commenting plans/specs in `docs/superpowers/` (Stages 6–9). This is a post-Stage-9 UI refinement; it adds no server-side behavior.

## Goal

Give the candidate page a global **Show / Hide comments** toggle — hidden pulls every thread out of the layout so the diff reads clean and response bodies can be selected and copied without comment cards interrupting them. While adding it, consolidate the page's **view-representation controls** into one home instead of scattering them: today "Highlight on scroll" sits on the sidebar (a nav widget) and Comment mode sits on the bottom toolbar pill. Both display toggles move into a **Display popover** on the pill; the sidebar returns to pure navigation.

## Scope & motivation

Two problems, one change:

1. **Comments pollute the read/copy path.** Line-anchored comment cards (`_inline_line_comment`) render *between* JSON `.line` rows inside response/entity bodies, so selecting a response body drags comment text into the selection. Region threads (`.anchor-strip`) add visual clutter too.
2. **View controls have no coherent home.** The sidebar's "Highlight on scroll" checkbox is a display preference bolted onto a quick-access nav panel. A second such checkbox would compound the smell.

Out of scope (deliberately): Edit stays a **header workflow action** (next to Merge/Reject), not a view mode; the Comment control stays a **simple toggle**, not a `View | Comment` segmented switch. See "Accepted / out of scope".

## The pill layout (`app/views/comments/_toolbar.html.erb`)

The existing floating bottom-center pill grows a second cluster, text-only (no emojis):

```
┌─ pill ──────────────────────────────┐
│  Comment          │   Display  v     │
└───────────────────────────┬─────────┘
              click Display ↑│
            ┌────────────────┴────────┐
            │  ☑  Highlight on scroll  │
            │  ☑  Show comments        │
            └─────────────────────────┘
```

- **Comment** — the existing mode toggle, behavior unchanged (`aria-pressed`, `C` shortcut). Drops its 💬 glyph.
- **Display** — a text button that opens a small popover above the pill holding the two display checkboxes. Click-outside and `Esc` close it.

**Built to grow.** The Display popover is the page's future home for view/display settings; it will accumulate toggles over time. So it's designed as a generic container, not a two-toggle special case: the popover is a plain list of controls, and `view_settings_controller` (below) manages toggles by convention rather than by hardcoded name — each toggle declares its localStorage key, body-class/event effect, and default via data attributes, so adding a new one is markup + (if it has bespoke behavior) a listener, with no structural churn.

## Hide / show comments

- A `body.comments-hidden` class drives CSS `display: none` on `.anchor-strip, .inline-line-comment, .candidate-conversation, [data-comment-form]`. `display:none` (not `visibility`) pulls the elements out of flow — this is what restores clean select-and-copy, not merely visual decluttering.
- `.anchor-strip` already wraps every region thread, line-thread group, and compose form. Three surfaces need their own hook: the inline between-lines cards get class **`.inline-line-comment`** on the `_inline_line_comment` wrapper; the candidate-level **Conversation** section gets **`.candidate-conversation`** (it's a comment surface but not an anchor strip); and **`[data-comment-form]`** covers a picked inline compose form that gets moved under its JSON row (outside `.anchor-strip`) while open.
- **Sidebar 💬 counts stay visible** — they are `comment_count_badge` spans in the sidebar, not `.anchor-strip`, so they are untouched and act as the "comments exist here" signal (consistent with the `comment-ui-conventions` badge ruling).
- Persist in `localStorage["papi.comments.hidden"]` (`"1"` / `"0"`), default **shown**. Mirrors the existing `papi.anchor.enabled` toggle.
- **No layout jump on comment-free cards.** Comment strips render even with zero threads (they host the composer for comment mode), so an empty strip reserves phantom vertical space that vanishes on hide: whole-endpoint/entity strips via their `mt-3`, and per-response line strips via the flex `gap` between the empty threads list and the non-hidden `form_home` composer wrapper. Every thread root gets a `.comment-thread` class, and `.anchor-strip:not(:has(.comment-thread)) { margin-top: 0; gap: 0 }` collapses both for composer-only strips — reactive via `:has()`, so posting the first comment restores the normal spacing without a reload.

## Highlight-on-scroll relocation

- Remove the checkbox + label from the sidebar markup (`_endpoints_and_entities.html.erb`, the `<label>…Highlight on scroll…</label>` block).
- The **control** moves to the Display popover; the **behavior** (scroll-spy that toggles `anchor-active` on cards) stays in `sidebar_controller`.
- Reuse the existing `localStorage["papi.anchor.enabled"]` key so persisted state carries over.

## Controllers

**New `view_settings_controller`** (attached to the pill) — owns the popover and its toggles generically, so the set can grow (see "Built to grow").

- Each toggle checkbox declares itself via data attributes: its `localStorage` key, its default (on/off), and an optional effect — a `body` class to toggle and/or window events to dispatch on change. The controller drives them uniformly; it does not name individual toggles.
- `connect()` — for every declared toggle, read its key (falling back to its default) and apply initial state: set the checkbox's `checked` and apply its body-class effect.
- Popover: `toggle()` open/close; close on outside-click and `Esc`.
- On a toggle change → persist its key, apply its body-class effect, and dispatch its declared window event(s).
- The two toggles at launch: **comments** (key `papi.comments.hidden`, body class `comments-hidden`, events `comments:hide` / `comments:show` for comment-mode coordination) and **highlight-on-scroll** (key `papi.anchor.enabled`, event `anchor:changed`, no body class — the sidebar owns the behavior).

**`comment_mode_controller`** (edit) — you can't comment on a hidden view, so the two stay consistent:

- Listens for `comments:hide` → `deactivate()`.
- `activate()` dispatches `comments:show` (un-hides if hidden).

No dispatch loops: `deactivate()` and the `show` path never re-emit the event that triggered them.

**`sidebar_controller`** (edit) — loses the `anchorToggle` target and `toggleAnchor` action. Keeps its connect-time read of `papi.anchor.enabled`, and additionally listens for `anchor:changed` → re-read the key and enable/clear its scroll-spy state. The behavior stays put; only the control relocates.

## Emojis

- Drop 💬 from the Comment button label; all static controls render emoji-free.
- The **comment-mode cursor pin stays 💬** — it is a functional cursor indicator (the one spot an icon genuinely aids the mode), not decorative static text. Reversible if we later want a plain dot.

## Testing

Purely front-end: a CSS class, two localStorage reads, and cross-controller window events — **no server-side change**, so no model / request / policy specs.

- Manual visual verification is primary: toggle hides all threads + inline cards, response body becomes cleanly selectable, sidebar counts remain, state survives reload, entering comment mode un-hides.
- Optional (only if it fits the existing system-test setup): a system test asserting the toggle adds `body.comments-hidden` and hides `.anchor-strip`. No new JS unit framework is introduced.

## Accepted / out of scope

- **Edit stays a header workflow action**, not a view mode — turning it into an in-place mode is a separate, larger change (inline editing vs. the current edit page).
- **Comment stays a simple toggle**, not a segmented `View | Comment` switch — same result, less churn.
- **Server-side render omission rejected** in favor of the CSS-class approach: the toggle must be instant and reload-free, and `display:none` already solves the copy problem.
- **Collapse-to-markers rejected** — it wouldn't fully fix copy (markers still interrupt the flow).
- **Sidebar 💬 counts stay visible** when comments are hidden.
- The Display popover open/close and both toggles are client-only; persistence is per-browser via localStorage, like the existing anchor toggle.
