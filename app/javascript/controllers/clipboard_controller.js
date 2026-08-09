import { Controller } from "@hotwired/stimulus"

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
