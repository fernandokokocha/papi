import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    highlight() {
        const el = this.anchorTarget()
        if (el) el.classList.add("anchor-highlight")
    }

    unhighlight() {
        const el = this.anchorTarget()
        if (el) el.classList.remove("anchor-highlight")
    }

    anchorTarget() {
        let el = this.element.previousElementSibling
        while (el && el.children.length === 0 && el.textContent.trim() === "") {
            el = el.previousElementSibling
        }
        return el
    }
}
