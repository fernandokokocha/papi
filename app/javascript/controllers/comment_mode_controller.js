import { Controller } from "@hotwired/stimulus"

// Figma-style comment mode for the candidate page. Toggled from the toolbar
// (or the "C" key). While on: the cursor becomes a 💬 pin, hovering a
// [data-comment-region] target outlines it (.anchor-highlight), and clicking
// opens that target's anchored compose form (#<dom_id>_form). Rows inside a
// [data-line-pick] tree are finer-grained targets: clicking one opens the
// block's line compose form (#<pick dom_id>_form) fed the row's canonical
// expanded-tree index; the form opens inline under the picked row when the
// block is expanded, or below the block when collapsed; the picked row
// keeps its outline until the form closes or the comment is posted. Stays
// on until Esc or toggled off.
// Threads / open compose / toolbar stay interactive; other in-target
// controls (Copy cURL, Expand) are suppressed.
export default class extends Controller {
  static targets = ["button", "pin"]

  connect() {
    this.onMove = this.onMove.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.deactivate()
    this.clearPick()
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
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
    this.hoverRow(null)
    // A pick backing an open composer survives leaving comment mode.
    if (!this.pickedForm || this.pickedForm.hidden) this.clearPick()
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("click", this.onClick, true)
  }

  onKey(e) {
    if (e.key === "Escape") {
      const open = e.target.closest && e.target.closest("[data-comment-form]")
      if (open) {
        open.hidden = true
        if (open === this.pickedForm) this.clearPick()
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
    if (e.target.closest(".anchor-strip") || e.target.closest("[data-comment-toolbar]") || e.target.closest("[data-comment-exempt]") || e.target.closest("[data-comment-form]")) {
      this.pinTarget.style.opacity = "0"
      this.clearHighlight()
      this.hoverRow(null)
      return
    }
    this.pinTarget.style.opacity = "1"
    this.pinTarget.style.left = e.clientX + "px"
    this.pinTarget.style.top = e.clientY + "px"
    const row = this.pickableRow(e.target)
    this.hoverRow(row)
    this.highlight(row ? null : e.target.closest("[data-comment-region]"))
  }

  onClick(e) {
    if (e.target.closest("[data-comment-close]")) {
      const f = e.target.closest("[data-comment-form]")
      if (f) {
        f.hidden = true
        if (f === this.pickedForm) this.clearPick()
      }
      return
    }
    if (e.target.closest("[data-comment-toolbar]") || e.target.closest(".anchor-strip") || e.target.closest("[data-comment-exempt]") || e.target.closest("[data-comment-form]")) return
    const row = this.pickableRow(e.target)
    if (row) {
      e.preventDefault()
      e.stopPropagation()
      this.pick(row)
      return
    }
    const t = e.target.closest("[data-comment-region]")
    if (!t) return
    e.preventDefault()
    e.stopPropagation()
    this.openCompose(t.getAttribute("data-comment-region"))
  }

  onSubmitEnd(e) {
    if (!this.pickedForm || !e.detail.success) return
    if (e.target.closest && e.target.closest("[data-comment-form]") === this.pickedForm) this.clearPick()
  }

  pickableRow(target) {
    const row = target.closest && target.closest("[data-line-index]")
    return row && row.closest("[data-line-pick]") ? row : null
  }

  pick(row) {
    const block = row.closest("[data-line-pick]")
    const form = document.getElementById(block.getAttribute("data-line-pick") + "_form")
    if (!form) return
    this.clearPick()
    this.picked = row
    this.pickedForm = form
    row.classList.add("line-picked")
    const line = row.getAttribute("data-line-index")
    form.querySelector("input[name='comment[line]']").value = line
    form.querySelector("[data-pick-label]").textContent = "📌 " + block.getAttribute("data-line-pick-label") + " · line " + line
    if (form.querySelector("input[name='expanded']").value === "true") {
      row.after(form)
      form.classList.add("my-1", "ml-4", "font-sans")
    } else {
      const home = document.getElementById(form.id + "_home")
      if (home && form.parentElement !== home) home.appendChild(form)
      form.classList.remove("my-1", "ml-4", "font-sans")
    }
    this.showForm(form)
  }

  clearPick() {
    if (this.picked) this.picked.classList.remove("line-picked")
    this.picked = null
    this.pickedForm = null
  }

  hoverRow(row) {
    if (this.hovered === row) return
    if (this.hovered) this.hovered.classList.remove("line-pick-highlight")
    this.hovered = row
    if (row) row.classList.add("line-pick-highlight")
  }

  openCompose(domId) {
    this.clearHighlight()
    this.clearPick()
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
