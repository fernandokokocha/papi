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
        const expanded_part = expanded ? "?expanded=true" : "?expanded=false"
        const url = this.urlValue + expanded_part
        fetch(url, {headers: {"Turbo": "false"}})
            .then(response => response.text())
            .then(html => {
                console.log(html);
                this.containerTarget.innerHTML = html
            })
    }
}