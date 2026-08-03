import { Controller } from "@hotwired/stimulus"

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
