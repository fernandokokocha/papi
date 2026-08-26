import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["container"]

    toggle(event) {
        this.render(event.params.url)
    }

    render(url) {
        fetch(url, {headers: {"Turbo": "false"}})
            .then(response => response.text())
            .then(html => {
                this.containerTarget.innerHTML = html
            })
    }
}
