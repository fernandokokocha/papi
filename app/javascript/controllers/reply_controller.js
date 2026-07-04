import { Controller } from "@hotwired/stimulus"

// Collapses a thread's reply form behind a "Reply…" trigger.
export default class extends Controller {
  static targets = ["trigger", "form"]

  show() {
    this.triggerTarget.hidden = true
    this.formTarget.hidden = false
    this.formTarget.querySelector("textarea").focus()
  }

  cancel() {
    this.formTarget.hidden = true
    this.triggerTarget.hidden = false
  }
}
