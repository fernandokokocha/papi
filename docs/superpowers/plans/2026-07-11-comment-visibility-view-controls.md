# Comment visibility + view-controls consolidation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global Show/Hide comments toggle and move the page's view-representation controls off the sidebar into a growable "Display" popover on the existing bottom toolbar pill.

**Architecture:** Pure front-end. A `body.comments-hidden` class (CSS `display:none` on `.anchor-strip, .inline-line-comment`) hides all threads and restores clean text selection. A new `view_settings_controller` drives a popover of checkbox toggles *by convention* (each declares its localStorage key, default, body-class effect, and window events via data attributes) so future toggles are markup-only. `comment_mode_controller` and `sidebar_controller` coordinate via window events, never reaching into each other's state.

**Tech Stack:** Rails ERB views, Stimulus (Hotwire), Tailwind v4. No server-side change; no new gems or JS deps.

## Global Constraints

- Governing spec: `docs/superpowers/specs/2026-07-11-comment-visibility-view-controls-design.md`. Binding memory: `comment-ui-conventions`.
- Write Tailwind classes as complete literal strings (no interpolation).
- Static controls render emoji-free; the comment-mode cursor pin (💬) stays.
- localStorage keys: `papi.comments.visible` (`"1"` visible / `"0"` hidden, default visible), `papi.anchor.enabled` (existing: enabled unless `"0"`). A checkbox stores `"1"` when checked.
- No automated test suite for this work — it's client CSS/JS/localStorage with no server surface. Each task ends with a **manual visual checkpoint**; do not proceed past a checkpoint without the user's confirmation.
- **Do not commit per-task.** A single commit lands at the end (Task 5) once the whole feature is verified.
- Assets: assume `bin/dev` is running (Vite + Tailwind watchers rebuild on save); just reload the page.

---

### Task 1: Hide/show CSS mechanism + inline-comment hook

**Files:**
- Modify: `app/assets/tailwind/application.css` (add rule near the other comment-UI rules, after `.line-pick-highlight`)
- Modify: `app/views/comments/_inline_line_comment.html.erb:1` (add `.inline-line-comment` class)
- Modify: `app/views/candidates/show.html.erb:55` (add `.candidate-conversation` class to the Conversation `<section>`)

**Interfaces:**
- Produces: the `body.comments-hidden` CSS contract and the `.inline-line-comment` hook that Task 2's toggle relies on.

- [ ] **Step 1: Add the CSS rule**

In `app/assets/tailwind/application.css`, after the `.line-pick-highlight { … }` block, add:

```css
/* Global "hide comments" (Display toolbox toggle): pull every thread and inline
   comment card out of layout so the diff reads clean and response bodies stay
   selectable. [data-comment-form] also covers a picked inline compose form,
   which gets moved under its JSON row (outside .anchor-strip) while open.
   Sidebar 💬 counts aren't .anchor-strip, so they stay visible. */
body.comments-hidden .anchor-strip,
body.comments-hidden .inline-line-comment,
body.comments-hidden .candidate-conversation,
body.comments-hidden [data-comment-form] { display: none; }
```

Then in `app/views/candidates/show.html.erb`, add the hook to the candidate-level Conversation section. Change `<section class="mt-10" data-comment-exempt>` to `<section class="mt-10 candidate-conversation" data-comment-exempt>`.

- [ ] **Step 2: Add the `.inline-line-comment` hook**

In `app/views/comments/_inline_line_comment.html.erb`, prepend the class to the wrapper. Change:

```erb
<div class="my-1 ml-4 border-l-2 border-l-sky-200 pl-3 font-sans"
```

to:

```erb
<div class="inline-line-comment my-1 ml-4 border-l-2 border-l-sky-200 pl-3 font-sans"
```

- [ ] **Step 3: Visual checkpoint**

Open a candidate page with both region threads and inline line comments. In devtools, add `class="commenting"`… actually add the class `comments-hidden` to `<body>`. Expected: every comment card (region strips **and** the cards nested between JSON lines) disappears; the response body text is now selectable/copyable in one clean sweep; sidebar 💬 counts remain. Remove the class → everything returns. **Confirm with the user before continuing.**

---

### Task 2: view_settings_controller + Display popover (comments toggle) + drop Comment emoji

**Files:**
- Create: `app/javascript/controllers/view_settings_controller.js`
- Modify: `app/views/comments/_toolbar.html.erb`

**Interfaces:**
- Consumes: `body.comments-hidden` / `.inline-line-comment` (Task 1).
- Produces:
  - Window events `comments:hide` (dispatched when the user hides comments) and support for an external `comments:reveal` request (consumed/produced in Task 3).
  - A generic toggle contract read from each `[data-view-settings-target="toggle"]` input's dataset: `data-key`, `data-default` (`"1"`/`"0"`), optional `data-body-class-off`, `data-body-class-on`, `data-change-event`, `data-on-event`, `data-off-event`, `data-reveal-event`, `data-conceal-event`.

- [ ] **Step 1: Write the controller**

Create `app/javascript/controllers/view_settings_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Bottom-pill "Display" popover: a growable set of view/display toggles.
// Each toggle is declared entirely by data attributes on its checkbox, so
// adding one is markup-only:
//   data-key            localStorage key (stores "1" checked / "0" unchecked)
//   data-default        "1" | "0" — state when the key is absent
//   data-body-class-off class toggled on <body> when the box is UNCHECKED
//   data-body-class-on  class toggled on <body> when the box is CHECKED
//   data-change-event   window event dispatched on any change
//   data-on-event       window event dispatched when turned on
//   data-off-event      window event dispatched when turned off
//   data-reveal-event   window event that forces this toggle ON externally
//   data-conceal-event  window event that forces this toggle OFF externally
export default class extends Controller {
  static targets = ["button", "panel", "toggle"]

  connect() {
    this.onOutside = this.onOutside.bind(this)
    this.onKey = this.onKey.bind(this)
    this.externalListeners = []

    this.toggleTargets.forEach((t) => {
      const stored = localStorage.getItem(t.dataset.key)
      t.checked = stored === null ? t.dataset.default === "1" : stored === "1"
      this.applyBodyClass(t)
      this.wireExternal(t, t.dataset.revealEvent, true)
      this.wireExternal(t, t.dataset.concealEvent, false)
    })
  }

  disconnect() {
    this.closePanel()
    this.externalListeners.forEach(([event, handler]) => window.removeEventListener(event, handler))
  }

  wireExternal(toggle, event, checked) {
    if (!event) return
    const handler = () => this.force(toggle, checked)
    window.addEventListener(event, handler)
    this.externalListeners.push([event, handler])
  }

  change(e) { this.apply(e.target) }

  // Force a toggle to a state from outside (e.g. comment mode revealing comments)
  // without echoing back — apply() only fires this toggle's own declared events.
  force(toggle, checked) {
    if (toggle.checked === checked) return
    toggle.checked = checked
    this.apply(toggle)
  }

  apply(toggle) {
    const checked = toggle.checked
    localStorage.setItem(toggle.dataset.key, checked ? "1" : "0")
    this.applyBodyClass(toggle)
    if (toggle.dataset.changeEvent) window.dispatchEvent(new Event(toggle.dataset.changeEvent))
    if (checked && toggle.dataset.onEvent) window.dispatchEvent(new Event(toggle.dataset.onEvent))
    if (!checked && toggle.dataset.offEvent) window.dispatchEvent(new Event(toggle.dataset.offEvent))
  }

  applyBodyClass(toggle) {
    if (toggle.dataset.bodyClassOff) document.body.classList.toggle(toggle.dataset.bodyClassOff, !toggle.checked)
    if (toggle.dataset.bodyClassOn) document.body.classList.toggle(toggle.dataset.bodyClassOn, toggle.checked)
  }

  togglePanel() { this.panelTarget.hidden ? this.openPanel() : this.closePanel() }

  openPanel() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.onOutside, true)
    document.addEventListener("keydown", this.onKey)
  }

  closePanel() {
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.onOutside, true)
    document.removeEventListener("keydown", this.onKey)
  }

  onOutside(e) { if (!this.element.contains(e.target)) this.closePanel() }
  onKey(e) { if (e.key === "Escape") this.closePanel() }
}
```

- [ ] **Step 2: Rework the toolbar markup**

Replace the whole contents of `app/views/comments/_toolbar.html.erb` with:

```erb
<div data-comment-toolbar class="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 bg-white border border-gray-200 rounded-full shadow-lg px-2.5 py-1.5">
  <button type="button"
          data-comment-mode-target="button"
          data-action="comment-mode#toggle"
          aria-pressed="false"
          class="inline-flex items-center gap-1.5 text-sm font-semibold text-gray-700 rounded-full px-3 py-1.5 cursor-pointer hover:bg-gray-50 aria-pressed:bg-sky-600 aria-pressed:text-white">
    Comment
  </button>
  <span class="text-xs text-gray-400 select-none pr-1">press <kbd class="font-mono">C</kbd></span>

  <span class="w-px h-5 bg-gray-200" aria-hidden="true"></span>

  <div class="relative" data-controller="view-settings">
    <button type="button"
            data-view-settings-target="button"
            data-action="view-settings#togglePanel"
            aria-expanded="false"
            class="inline-flex items-center gap-1 text-sm font-semibold text-gray-700 rounded-full px-3 py-1.5 cursor-pointer hover:bg-gray-50 aria-expanded:bg-gray-100">
      Display <span aria-hidden="true" class="text-xs text-gray-400">▾</span>
    </button>
    <div data-view-settings-target="panel" hidden
         class="absolute bottom-full right-0 mb-2 w-56 bg-white border border-gray-200 rounded-lg shadow-lg p-2 flex flex-col gap-0.5">
      <label class="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-gray-50 text-sm text-gray-700 cursor-pointer select-none">
        <input type="checkbox"
               data-view-settings-target="toggle"
               data-action="view-settings#change"
               data-key="papi.comments.visible" data-default="1"
               data-body-class-off="comments-hidden" data-off-event="comments:hide"
               data-reveal-event="comments:reveal"
               class="accent-sky-600 cursor-pointer">
        <span>Show comments</span>
      </label>
    </div>
  </div>
</div>
<span data-comment-mode-target="pin" class="comment-pin" aria-hidden="true">💬</span>
```

- [ ] **Step 3: Visual checkpoint**

Reload the candidate page. Expected: the pill reads `Comment  press C  |  Display ▾` with no 💬 on the Comment button. Click **Display** → popover opens above the pill with a checked "Show comments"; click outside or press Esc → closes. Uncheck "Show comments" → all comment cards vanish and the response body copies cleanly; reload → still hidden (persisted). Re-check → comments return. **Confirm with the user before continuing.**

---

### Task 3: Comment-mode coordination

**Files:**
- Modify: `app/javascript/controllers/comment_mode_controller.js` (`connect`, `disconnect`, `activate`)

**Interfaces:**
- Consumes: `comments:hide` (Task 2) and the `comments:reveal` reveal-event wired on the comments toggle (Task 2).
- Produces: dispatches `comments:reveal` when comment mode activates.

- [ ] **Step 1: Bind and register the hide listener**

In `comment_mode_controller.js`, in `connect()`, after the existing `this.onSubmitEnd = this.onSubmitEnd.bind(this)` line add:

```javascript
    this.onCommentsHide = () => this.deactivate()
```

and after the existing `document.addEventListener("turbo:submit-end", this.onSubmitEnd)` line add:

```javascript
    window.addEventListener("comments:hide", this.onCommentsHide)
```

- [ ] **Step 2: Remove the listener on disconnect**

In `disconnect()`, after `document.removeEventListener("turbo:submit-end", this.onSubmitEnd)` add:

```javascript
    window.removeEventListener("comments:hide", this.onCommentsHide)
```

- [ ] **Step 3: Reveal comments when entering comment mode**

In `activate()`, make it the first line of the method body (before `this.active = true`):

```javascript
    window.dispatchEvent(new Event("comments:reveal"))
```

- [ ] **Step 4: Visual checkpoint**

Reload. (a) Enter comment mode (click Comment or press `C`), then open Display and uncheck "Show comments" → comment mode turns off (pill button un-presses, 💬 pin gone) and comments hide. (b) With comments hidden, press `C` → comments reappear (checkbox re-checks) and comment mode activates. No flicker/loops. **Confirm with the user before continuing.**

---

### Task 4: Relocate "Highlight on scroll" into the popover

**Files:**
- Modify: `app/views/comments/_toolbar.html.erb` (add the highlight toggle to the popover)
- Modify: `app/views/versions/_endpoints_and_entities.html.erb` (remove the sidebar checkbox label, lines 17–23)
- Modify: `app/javascript/controllers/sidebar_controller.js`

**Interfaces:**
- Consumes: `view-settings` generic toggle contract (Task 2); `papi.anchor.enabled` (existing).
- Produces: window event `anchor:changed` (dispatched by the toggle), consumed by `sidebar_controller`.

- [ ] **Step 1: Add the highlight toggle to the popover**

In `app/views/comments/_toolbar.html.erb`, inside the `data-view-settings-target="panel"` div, add as the **first** label (above "Show comments"):

```erb
      <label class="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-gray-50 text-sm text-gray-700 cursor-pointer select-none">
        <input type="checkbox"
               data-view-settings-target="toggle"
               data-action="view-settings#change"
               data-key="papi.anchor.enabled" data-default="1"
               data-change-event="anchor:changed"
               class="accent-sky-600 cursor-pointer">
        <span>Highlight on scroll</span>
      </label>
```

- [ ] **Step 2: Remove the sidebar checkbox**

In `app/views/versions/_endpoints_and_entities.html.erb`, delete the label block (currently lines 17–23):

```erb
    <label class="flex items-center gap-1.5 mb-1.5 pb-1.5 border-b border-gray-200 text-xs text-gray-500 cursor-pointer select-none">
      <input type="checkbox"
             data-sidebar-target="anchorToggle"
             data-action="sidebar#toggleAnchor"
             class="accent-sky-600 cursor-pointer">
      <span>Highlight on scroll</span>
    </label>
```

- [ ] **Step 3: Rewire `sidebar_controller`**

In `app/javascript/controllers/sidebar_controller.js`:

(a) Drop `"anchorToggle"` from the targets list:

```javascript
  static targets = ["aside", "showButton", "link", "card"]
```

(b) In `connect()`, replace the line `if (this.hasAnchorToggleTarget) this.anchorToggleTarget.checked = this.anchorEnabled` with a window-event listener. So this block:

```javascript
    // Scroll-spy is opt-out; default on unless the user disabled it before.
    this.anchorEnabled = localStorage.getItem(this.constructor.anchorKey) !== "0"
    if (this.hasAnchorToggleTarget) this.anchorToggleTarget.checked = this.anchorEnabled
```

becomes:

```javascript
    // Scroll-spy is opt-out; default on unless the user disabled it before.
    // The control lives in the Display popover; it flips localStorage and fires
    // "anchor:changed", which we re-read here.
    this.anchorEnabled = localStorage.getItem(this.constructor.anchorKey) !== "0"
    this.onAnchorChanged = this.applyAnchorSetting.bind(this)
    window.addEventListener("anchor:changed", this.onAnchorChanged)
```

(c) In `disconnect()`, add:

```javascript
    window.removeEventListener("anchor:changed", this.onAnchorChanged)
```

(d) Replace the `toggleAnchor()` method with `applyAnchorSetting()`:

```javascript
  // Re-read the anchor setting after the Display popover changed it.
  applyAnchorSetting() {
    this.anchorEnabled = localStorage.getItem(this.constructor.anchorKey) !== "0"
    if (this.anchorEnabled) {
      this.updateCurrent()
    } else {
      this.pinnedId = null
      this.clearAnchor()
    }
  }
```

- [ ] **Step 4: Visual checkpoint**

Reload. Expected: the sidebar no longer shows the "Highlight on scroll" checkbox (pure nav now). Open Display → both "Highlight on scroll" (checked) and "Show comments" appear. Scroll the page → a card/link is highlighted as before. Uncheck "Highlight on scroll" → highlighting stops immediately; reload → still off; re-check → highlighting resumes. **Confirm with the user before continuing.**

---

### Task 5: Final review + commit

- [ ] **Step 1: Full regression sweep**

On a candidate page, exercise together: comment mode on/off (button + `C` + Esc), posting a comment, hovering a thread (region + inline highlight still work), both Display toggles, persistence across reload, and clean copy of a response body while comments are hidden. Confirm no console errors.

- [ ] **Step 2: Lint**

Run: `bin/rubocop`
Expected: no new offenses in the touched ERB. (JS is not covered by rubocop.)

- [ ] **Step 3: Commit (only after the user confirms the whole feature)**

```bash
git add app/assets/tailwind/application.css \
        app/views/comments/_inline_line_comment.html.erb \
        app/views/comments/_toolbar.html.erb \
        app/views/versions/_endpoints_and_entities.html.erb \
        app/javascript/controllers/view_settings_controller.js \
        app/javascript/controllers/comment_mode_controller.js \
        app/javascript/controllers/sidebar_controller.js \
        docs/superpowers/specs/2026-07-11-comment-visibility-view-controls-design.md \
        docs/superpowers/plans/2026-07-11-comment-visibility-view-controls.md
git commit -m "Add global hide/show comments toggle + Display popover"
```
