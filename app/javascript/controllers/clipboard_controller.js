import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { verb: String, path: String, response: String, query: String }

  async copy() {
    const base = location.origin + location.pathname
    const parts = []
    if (this.responseValue) parts.push(`response=${this.responseValue}`)
    if (this.queryValue) parts.push(this.queryValue)
    const query = parts.length ? `?${parts.join("&")}` : ""
    const cmd = `curl -X ${this.verbValue} "${base}${this.pathValue}${query}"`
    try {
      await navigator.clipboard.writeText(cmd)
      this.element.dataset.copied = ""
      setTimeout(() => { delete this.element.dataset.copied }, 1200)
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }
}
