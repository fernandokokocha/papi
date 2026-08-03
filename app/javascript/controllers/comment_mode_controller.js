import { Controller } from "@hotwired/stimulus"
import { isExempt } from "helpers/commentTargets"
import { LinePicker } from "helpers/linePicker"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.picker = new LinePicker()
    this.onMove = this.onMove.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    this.onCommentsHide = () => this.deactivate()
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    window.addEventListener("comments:hide", this.onCommentsHide)
  }

  disconnect() {
    this.deactivate()
    this.picker.clear()
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    window.removeEventListener("comments:hide", this.onCommentsHide)
  }

  toggle() { this.active ? this.deactivate() : this.activate() }

  activate() {
    window.dispatchEvent(new Event("comments:reveal"))
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
    this.picker.hover(null)
    // A pick backing an open composer survives leaving comment mode.
    if (!this.picker.form || this.picker.form.hidden) this.picker.clear()
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("click", this.onClick, true)
  }

  onKey(e) {
    if (e.key === "Escape") {
      const open = e.target.closest && e.target.closest("[data-comment-form]")
      if (open) {
        open.hidden = true
        if (open === this.picker.form) this.picker.clear()
        this.buttonTarget.focus()
        return
      }
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
    if (isExempt(e.target)) {
      this.clearHighlight()
      this.picker.hover(null)
      return
    }
    const row = LinePicker.rowIn(e.target)
    this.picker.hover(row)
    this.highlight(row ? null : e.target.closest("[data-comment-region]"))
  }

  onClick(e) {
    if (e.target.closest("[data-comment-close]")) {
      const f = e.target.closest("[data-comment-form]")
      if (f) {
        f.hidden = true
        if (f === this.picker.form) this.picker.clear()
      }
      return
    }
    if (isExempt(e.target)) return
    const row = LinePicker.rowIn(e.target)
    if (row) {
      e.preventDefault()
      e.stopPropagation()
      const form = this.picker.pick(row)
      if (form) this.showForm(form)
      return
    }
    const t = e.target.closest("[data-comment-region]")
    if (!t) return
    e.preventDefault()
    e.stopPropagation()
    this.openCompose(t.getAttribute("data-comment-region"))
  }

  onSubmitEnd(e) {
    if (!this.picker.form || !e.detail.success) return
    if (e.target.closest && e.target.closest("[data-comment-form]") === this.picker.form) this.picker.clear()
  }

  openCompose(domId) {
    this.clearHighlight()
    this.picker.clear()
    const form = document.getElementById(domId + "_form")
    if (form) this.showForm(form)
  }

  showForm(form) {
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
