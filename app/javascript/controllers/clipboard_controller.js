import { Controller } from "@hotwired/stimulus"

// Copies a cURL command for an endpoint to the clipboard.
// Reads verb/path from data-clipboard-*-value. Builds base URL from window.location.
export default class extends Controller {
  static values = { verb: String, path: String }

  async copy(event) {
    const base = location.origin + location.pathname
    const cmd = `curl -X ${this.verbValue} "${base}${this.pathValue}"`
    try {
      await navigator.clipboard.writeText(cmd)
      const btn = event.currentTarget
      const original = btn.textContent
      btn.textContent = "Copied!"
      setTimeout(() => { btn.textContent = original }, 1200)
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }
}
