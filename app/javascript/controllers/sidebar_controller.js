import { Controller } from "@hotwired/stimulus"

// Toggles the quick-access sidebar on version/candidate pages.
// Persists collapsed state in localStorage so it survives navigations.
export default class extends Controller {
  static targets = ["aside", "showButton"]
  static storageKey = "papi.sidebar.collapsed"

  connect() {
    this.apply(localStorage.getItem(this.constructor.storageKey) === "1")
    this.onDocClick = this.handleDocClick.bind(this)
    document.addEventListener("click", this.onDocClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
  }

  handleDocClick(event) {
    if (!location.hash) return
    const el = event.target.closest('a[href^="#"], [id^="endpoint-"], [id^="entity-"]')
    if (el) return
    history.replaceState(null, "", location.pathname + location.search)
    // Force :target re-evaluation by briefly navigating to a non-matching hash.
    location.hash = "_"
    history.replaceState(null, "", location.pathname + location.search)
  }

  toggle() {
    const collapsed = !this.asideTarget.classList.contains("hidden")
    localStorage.setItem(this.constructor.storageKey, collapsed ? "1" : "0")
    this.apply(collapsed)
  }

  apply(collapsed) {
    this.asideTarget.classList.toggle("hidden", collapsed)
    this.showButtonTarget.classList.toggle("hidden", !collapsed)
  }
}
