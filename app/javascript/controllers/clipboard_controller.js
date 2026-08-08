import { Controller } from "@hotwired/stimulus"

// Copies a cURL command for a single response to the clipboard.
// Reads verb/path/response/query from data-clipboard-*-value. Builds base URL
// from window.location, targets a specific response code via ?response=, and
// appends the endpoint's declared query params with their kinds as placeholders.
export default class extends Controller {
  static values = { verb: String, path: String, response: String, query: String }

  async copy(event) {
    const base = location.origin + location.pathname
    const parts = []
    if (this.responseValue) parts.push(`response=${this.responseValue}`)
    if (this.queryValue) parts.push(this.queryValue)
    const query = parts.length ? `?${parts.join("&")}` : ""
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
