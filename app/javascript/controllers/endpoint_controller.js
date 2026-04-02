import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["container"]
    static values = {url: String}

    expand() {
        this.makeCall(true)
    }

    collapse() {
        this.makeCall(false)
    }

    makeCall(expanded) {
        const separator = this.urlValue.includes('?') ? '&' : '?'
        const url = this.urlValue + separator + 'expanded=' + expanded
        fetch(url, {headers: {"Turbo": "false"}})
            .then(response => response.text())
            .then(html => {
                this.containerTarget.innerHTML = html
            })
    }
}