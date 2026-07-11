import { Controller } from "@hotwired/stimulus"

// Hovering an inline line comment outlines the source row it is anchored to —
// the [data-line-index] row inside the [data-line-pick] tree it was pinned to.
export default class extends Controller {
  static values = { pick: String, line: Number }

  on() { this.row()?.classList.add("anchor-highlight") }
  off() { this.row()?.classList.remove("anchor-highlight") }

  row() {
    return document.querySelector(
      `[data-line-pick="${this.pickValue}"] [data-line-index="${this.lineValue}"]`
    )
  }
}
