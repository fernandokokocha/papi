import { Controller } from "@hotwired/stimulus"

// An op answers with most of the page and takes long enough to notice, so the
// form is held still until the answer lands rather than taking edits against
// markup that is already being replaced.
export default class extends Controller {
  static targets = ["backdrop"]

  lock() {
    this.backdropTarget.classList.remove("hidden")
  }

  unlock() {
    this.backdropTarget.classList.add("hidden")
  }
}
