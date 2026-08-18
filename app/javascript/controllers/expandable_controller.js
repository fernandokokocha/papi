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

    toggle(event) {
        this.render(event.params.url)
    }

    makeCall(expanded) {
        const separator = this.urlValue.includes('?') ? '&' : '?'
        this.render(this.urlValue + separator + 'expanded=' + expanded)
    }

    render(url) {
        fetch(url, {headers: {"Turbo": "false"}})
            .then(response => response.text())
            .then(html => {
                this.containerTarget.innerHTML = html
            })
    }
}
