import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.lift(true)
    this.dispatch("open")
  }

  close() {
    if (this.panelTarget.hidden) return

    this.panelTarget.hidden = true
    this.lift(false)
    this.dispatch("close")
  }

  dismiss(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  // A card header is sticky with a z-index, so it traps the panel in its own
  // stacking context and the next card's header paints over it.
  lift(open) {
    const header = this.element.closest(".sticky")
    if (header) header.classList.toggle("margin-note-open", open)
  }
}
