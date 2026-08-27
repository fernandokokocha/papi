import { Controller } from "@hotwired/stimulus"

// An op answers with most of the page and takes long enough to notice, so the
// form is held still until the answer lands rather than taking edits against
// markup that is already being replaced.
export default class extends Controller {
  static targets = ["backdrop"]
  static values = { formId: String }

  connect() {
    this.pendingSave = false
    this.onPointerDown = this.rememberSave.bind(this)
    this.element.addEventListener("pointerdown", this.onPointerDown)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPointerDown)
  }

  // Saving straight out of an edited field blurs it, and the op that blur fires
  // covers the bar and re-renders the button before its click can land. Pointer
  // down still reaches it, so the intent is taken there and spent on unlock.
  rememberSave(event) {
    this.pendingSave = event.target.closest(`button[form="${this.formIdValue}"]`) !== null
  }

  lock(event) {
    if (event.target === this.saveForm) this.pendingSave = false
    this.backdropTarget.classList.remove("hidden")
  }

  unlock() {
    this.backdropTarget.classList.add("hidden")
    if (!this.pendingSave) return

    this.pendingSave = false
    if (this.saveButton) this.saveForm.requestSubmit()
  }

  get saveForm() {
    return document.getElementById(this.formIdValue)
  }

  // The op may have answered with a problem, which withdraws the button.
  get saveButton() {
    return this.element.querySelector(`button[form="${this.formIdValue}"]`)
  }
}
