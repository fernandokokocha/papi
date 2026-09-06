import { Controller } from "@hotwired/stimulus"

// Every row of the page chooses from one of a handful of lists, and stamping
// them into three hundred and eighty selects is a fifth of what the page
// weighs. The server still decides everything — which list a select may read,
// and which of its names a one-of's sibling has already taken. This copies the
// list it was pointed at, the first time the select is opened.
export default class extends Controller {
  static values = { source: String, taken: String }

  fill() {
    if (this.filled) return

    const chosen = this.element.value
    const taken = this.takenValue ? this.takenValue.split(",") : []

    this.element.innerHTML = document.getElementById(this.sourceValue).innerHTML
    this.element.querySelectorAll("option")
      .forEach((option) => { if (taken.includes(option.text)) option.remove() })
    this.element.querySelectorAll("optgroup")
      .forEach((group) => { if (group.children.length === 0) group.remove() })

    this.element.value = chosen
    this.filled = true
  }
}
