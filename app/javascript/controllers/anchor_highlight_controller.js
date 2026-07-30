import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { region: String }

  on() { this.anchorEls().forEach(el => el.classList.add("anchor-highlight")) }
  off() { this.anchorEls().forEach(el => el.classList.remove("anchor-highlight")) }

  anchorEls() {
    return document.querySelectorAll(`[data-comment-region="${this.regionValue}"]`)
  }
}
