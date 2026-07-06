import { Controller } from "@hotwired/stimulus"

// Figma-style comment mode for the candidate page. Toggled from the toolbar
// (or the "C" key). While on: the cursor becomes a 💬 pin, hovering a
// [data-comment-region] target outlines it (.anchor-highlight), and clicking
// opens that target's anchored compose form (#<dom_id>_form). Stays on until
// Esc or toggled off. Threads / open compose / toolbar stay interactive; other
// in-target controls (Copy cURL, Expand) are suppressed while on.
export default class extends Controller {
  static targets = ["button", "pin"]

  connect() {
    this.onMove = this.onMove.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    this.deactivate()
    document.removeEventListener("keydown", this.onKey)
  }

  toggle() { this.active ? this.deactivate() : this.activate() }

  activate() {
    this.active = true
    document.body.classList.add("commenting")
    this.buttonTarget.setAttribute("aria-pressed", "true")
    document.addEventListener("mousemove", this.onMove)
    document.addEventListener("click", this.onClick, true)
  }

  deactivate() {
    if (!this.active) return
    this.active = false
    document.body.classList.remove("commenting")
    this.buttonTarget.setAttribute("aria-pressed", "false")
    this.clearHighlight()
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("click", this.onClick, true)
  }

  onKey(e) {
    if (e.key === "Escape") {
      const open = e.target.closest && e.target.closest("[data-comment-form]")
      if (open) { open.hidden = true; this.buttonTarget.focus(); return }
      if (this.active) this.deactivate()
      return
    }
    const el = document.activeElement
    const typing = el && /^(TEXTAREA|INPUT|SELECT)$/.test(el.tagName)
    if ((e.key === "c" || e.key === "C") && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
      e.preventDefault()
      this.toggle()
    }
  }

  onMove(e) {
    if (e.target.closest(".anchor-strip") || e.target.closest("[data-comment-toolbar]") || e.target.closest("[data-comment-exempt]")) {
      this.pinTarget.style.opacity = "0"
      this.clearHighlight()
      return
    }
    this.pinTarget.style.opacity = "1"
    this.pinTarget.style.left = e.clientX + "px"
    this.pinTarget.style.top = e.clientY + "px"
    this.highlight(e.target.closest("[data-comment-region]"))
  }

  onClick(e) {
    if (e.target.closest("[data-comment-close]")) {
      const f = e.target.closest("[data-comment-form]")
      if (f) f.hidden = true
      return
    }
    if (e.target.closest("[data-comment-toolbar]") || e.target.closest(".anchor-strip") || e.target.closest("[data-comment-exempt]")) return
    const t = e.target.closest("[data-comment-region]")
    if (!t) return
    e.preventDefault()
    e.stopPropagation()
    this.openCompose(t.getAttribute("data-comment-region"))
  }

  openCompose(domId) {
    this.clearHighlight()
    const form = document.getElementById(domId + "_form")
    if (!form) return
    // Only one anchored composer open at a time — close any other.
    document.querySelectorAll("[data-comment-form]:not([hidden])").forEach(f => { if (f !== form) f.hidden = true })
    form.hidden = false
    const ta = form.querySelector("textarea")
    if (ta) ta.focus()
  }

  highlight(el) {
    if (this.hl === el) return
    this.clearHighlight()
    this.hl = el
    if (el) el.classList.add("anchor-highlight")
  }

  clearHighlight() {
    if (this.hl) { this.hl.classList.remove("anchor-highlight"); this.hl = null }
  }
}
