import { Controller } from "@hotwired/stimulus"
import { isExempt } from "helpers/commentTargets"

export default class extends Controller {
  connect() {
    this.onMove = this.onMove.bind(this)
    document.addEventListener("mousemove", this.onMove)
  }

  disconnect() {
    document.removeEventListener("mousemove", this.onMove)
  }

  onMove(event) {
    if (!document.body.classList.contains("commenting")) return

    this.element.style.opacity = isExempt(event.target) ? "0" : "1"
    this.element.style.left = event.clientX + "px"
    this.element.style.top = event.clientY + "px"
  }
}
