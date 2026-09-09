import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { verb: String, path: String, response: String, query: String, mockToken: String, authorization: String }

  async copy() {
    const base = location.origin + location.pathname
    const parts = []
    if (this.responseValue) parts.push(`response=${this.responseValue}`)
    if (this.queryValue) parts.push(this.queryValue)
    parts.push(`mock_token=${this.mockTokenValue}`)
    const query = `?${parts.join("&")}`
    const header = this.authorizationValue ? ` -H "Authorization: ${this.authorizationValue}"` : ""
    const cmd = `curl -X ${this.verbValue}${header} "${base}${this.pathValue}${query}"`
    try {
      await navigator.clipboard.writeText(cmd)
      this.element.dataset.copied = ""
      setTimeout(() => { delete this.element.dataset.copied }, 1200)
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }
}
