import { Controller } from "@hotwired/stimulus"

// The bar menu and each sidebar section hold the same three fields, and both
// hosts submit into the one ops form, so a field that is not being filled in
// stays disabled and opening one host closes the other.
export default class extends Controller {
  static targets = ["panel", "item", "field"]
  static values = { host: String, open: String }

  connect() {
    this.onOpened = (event) => {
      if (event.detail.host !== this.hostValue) this.close()
    }
    window.addEventListener("new-form:opened", this.onOpened)

    if (this.openValue) this.reveal(this.openValue)
  }

  disconnect() {
    window.removeEventListener("new-form:opened", this.onOpened)
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.panelTarget.classList.remove("hidden")
      window.dispatchEvent(new CustomEvent("new-form:opened", { detail: { host: this.hostValue } }))
    } else {
      this.close()
    }
  }

  ask(event) {
    event.preventDefault()
    this.reveal(event.currentTarget.dataset.kind)
    window.dispatchEvent(new CustomEvent("new-form:opened", { detail: { host: this.hostValue } }))
  }

  close() {
    if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
    this.itemTargets.forEach((item) => item.classList.remove("hidden"))
    this.fieldTargets.forEach((field) => {
      field.classList.add("hidden")
      this.controls(field).forEach((control) => { control.disabled = true })
    })
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  reveal(kind) {
    this.close()

    const details = this.element.querySelector("details")
    if (details) details.open = true
    if (this.hasPanelTarget) this.panelTarget.classList.remove("hidden")

    this.itemTargets.filter((item) => item.dataset.kind === kind).forEach((item) => item.classList.add("hidden"))

    const field = this.fieldTargets.find((candidate) => candidate.dataset.kind === kind)
    field.classList.remove("hidden")
    this.controls(field).forEach((control) => { control.disabled = false })
    field.querySelector("input").focus()
  }

  controls(field) {
    return field.querySelectorAll("input, select, button[type=submit]")
  }
}
