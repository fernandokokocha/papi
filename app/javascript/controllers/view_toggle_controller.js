import { Controller } from "@hotwired/stimulus"

// Page-level Table ⇄ Timeline switch for the projects history. Sets
// data-view on the wrapper (CSS drives visibility + active tab styling)
// and remembers the choice in localStorage.
export default class extends Controller {
  static values = { default: String }

  connect() {
    const stored = localStorage.getItem("projects-view")
    this.apply(stored || this.defaultValue || "table")
  }

  show(event) {
    this.apply(event.params.view)
  }

  apply(view) {
    this.element.dataset.view = view
    localStorage.setItem("projects-view", view)
  }
}
