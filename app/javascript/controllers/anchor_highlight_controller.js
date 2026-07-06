import { Controller } from "@hotwired/stimulus"

// Hovering a comment thread outlines the target it is anchored to — every
// [data-comment-region] element sharing this region's dom_id (both note or
// response cells, or the whole endpoint/entity card). Works in and out of
// comment mode.
export default class extends Controller {
  static values = { region: String }

  on() { this.anchorEls().forEach(el => el.classList.add("anchor-highlight")) }
  off() { this.anchorEls().forEach(el => el.classList.remove("anchor-highlight")) }

  anchorEls() {
    return document.querySelectorAll(`[data-comment-region="${this.regionValue}"]`)
  }
}
