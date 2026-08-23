import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  submit() {
    const button = document.createElement("button")
    button.type = "submit"
    button.hidden = true
    button.formAction = this.urlValue.replace("__VALUE__", encodeURIComponent(this.element.value))

    this.element.form.appendChild(button)
    this.element.form.requestSubmit(button)
    button.remove()
  }

  commit(event) {
    event.preventDefault()
    this.element.blur()
  }
}
