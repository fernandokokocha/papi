import { Controller } from "@hotwired/stimulus"

// Copies a cURL command for a single response to the clipboard.
// Reads verb/path/response from data-clipboard-*-value. Builds base URL from
// window.location and targets a specific response code via ?response=.
export default class extends Controller {
  static values = { verb: String, path: String, response: String }

  async copy(event) {
    const base = location.origin + location.pathname
    const query = this.responseValue ? `?response=${this.responseValue}` : ""
    const cmd = `curl -X ${this.verbValue} "${base}${this.pathValue}${query}"`
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
