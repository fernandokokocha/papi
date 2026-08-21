import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["card"]

    show() {
        this.cardTarget.showPopover()
        this.place()
    }

    hide() {
        this.cardTarget.hidePopover()
    }

    place() {
        const badge = this.element.getBoundingClientRect()
        const card = this.cardTarget.getBoundingClientRect()
        const below = badge.bottom + 6

        this.cardTarget.style.left = `${Math.min(badge.left, window.innerWidth - card.width - 12)}px`
        this.cardTarget.style.top = `${below + card.height > window.innerHeight ? badge.top - card.height - 6 : below}px`
    }
}
