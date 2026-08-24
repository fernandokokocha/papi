import {Controller} from "@hotwired/stimulus"
import anchorToBadge from "helpers/anchorToBadge"

export default class extends Controller {
    static targets = ["card"]

    show() {
        this.cardTarget.showPopover()
        anchorToBadge(this.element, this.cardTarget)
    }

    hide() {
        this.cardTarget.hidePopover()
    }
}
