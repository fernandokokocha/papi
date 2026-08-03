export class LinePicker {
  constructor() {
    this.row = null
    this.form = null
    this.hovered = null
  }

  static rowIn(target) {
    const row = target.closest && target.closest("[data-line-index]")
    return row && row.closest("[data-line-pick]") ? row : null
  }

  pick(row) {
    const block = row.closest("[data-line-pick]")
    const form = document.getElementById(block.getAttribute("data-line-pick") + "_form")
    if (!form) return null

    this.clear()
    this.row = row
    this.form = form
    row.classList.add("line-picked")
    this.label(form, block, row.getAttribute("data-line-index"))
    this.place(form, row)
    return form
  }

  clear() {
    if (this.row) this.row.classList.remove("line-picked")
    this.row = null
    this.form = null
  }

  hover(row) {
    if (this.hovered === row) return
    if (this.hovered) this.hovered.classList.remove("line-pick-highlight")
    this.hovered = row
    if (row) row.classList.add("line-pick-highlight")
  }

  label(form, block, line) {
    form.querySelector("input[name='comment[line]']").value = line
    form.querySelector("[data-pick-label]").textContent =
      `📌 ${block.getAttribute("data-line-pick-label")} · line ${line}`
  }

  place(form, row) {
    if (form.querySelector("input[name='expanded']").value === "true") {
      row.after(form)
      form.classList.add("my-1", "ml-4", "font-sans")
    } else {
      const home = document.getElementById(`${form.id}_home`)
      if (home && form.parentElement !== home) home.appendChild(form)
      form.classList.remove("my-1", "ml-4", "font-sans")
    }
  }
}
