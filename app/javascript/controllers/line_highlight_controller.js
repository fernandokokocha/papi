import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { pick: String, line: Number }

  on() { this.row()?.classList.add("anchor-highlight") }
  off() { this.row()?.classList.remove("anchor-highlight") }

  row() {
    const rows = document.querySelectorAll(`[data-line-pick="${this.pickValue}"] [data-line-index]`)
    let containing = null
    for (const row of rows) {
      if (Number(row.getAttribute("data-line-index")) > this.lineValue) break
      containing = row
    }
    return containing
  }
}
