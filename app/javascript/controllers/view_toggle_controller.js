import { Controller } from "@hotwired/stimulus"

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
