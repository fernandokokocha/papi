import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["home", "form"]

  // One form for the whole page, lent to whichever pin panel is open.
  attach(event) {
    const slot = event.target.querySelector("[data-composer-slot]")
    if (!slot) return

    const anchor = JSON.parse(event.target.dataset.commentAnchor)
    Object.entries(anchor).forEach(([ column, value ]) => {
      this.formTarget.elements[`comment[${column}]`].value = value ?? ""
    })
    this.formTarget.elements["sublabel"].value = event.target.dataset.commentSublabel ?? ""

    slot.appendChild(this.formTarget)
    this.formTarget.elements["comment[body]"].focus()
  }

  park() {
    this.homeTarget.appendChild(this.formTarget)
  }

  // The stream replaces the panel the form is sitting in, so it goes home
  // before the response lands rather than being torn out with it.
  submitted(event) {
    if (event.target !== this.formTarget) return
    this.formTarget.elements["comment[body]"].value = ""
    this.park()
  }
}
