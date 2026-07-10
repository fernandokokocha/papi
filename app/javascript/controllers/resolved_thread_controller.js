import { Controller } from "@hotwired/stimulus"

// Reveals a resolved thread's full body (comments, replies, reply form)
// when its collapsed summary is toggled. Reopening is a separate button_to.
export default class extends Controller {
  static targets = ["body"]

  toggle() {
    this.bodyTarget.hidden = !this.bodyTarget.hidden
  }
}
