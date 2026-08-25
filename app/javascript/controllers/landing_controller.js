import { Controller } from "@hotwired/stimulus"

// The card an op just made arrives inside a replaced list, so it takes the page
// to itself rather than waiting to be scrolled to.
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
