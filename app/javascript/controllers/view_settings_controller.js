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
