import {Controller} from "@hotwired/stimulus"
import anchorToBadge from "helpers/anchorToBadge"

// The badge opens the panel through popovertarget, so dismissing it — a click
// outside, Escape — is the browser's job. All that is left is placing it.
export default class extends Controller {
    static targets = ["badge", "panel"]

    place(event) {
        if (event.newState !== "open") return

        anchorToBadge(this.badgeTarget, this.panelTarget)
        this.panelTarget.querySelector("textarea").focus()
    }
}
