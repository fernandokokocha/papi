import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["endpointRoot"]

    connect() {
        this.update()
    }

    update() {
        const newValue = this.readObject(this.endpointRootTarget.nextElementSibling)
        this.endpointRootTarget.setAttribute("value", newValue)
    }

    readObject(element) {
        const attributes = Array.from(element.children).filter((c) => c.className == "endpoint_form_object_attribute")
        return `{${attributes.map((e) => this.mapAttribute(e))}}`
    }

    mapAttribute(element) {
        const name = element.children[0].innerText
        const span = element.children[1]
        const select = span.children[0]
        let value
        if (select.value === "object") {
            value = this.readObject(span.nextElementSibling)
        } else {
            value = select.value
        }
        return `${name}:${value}`
    }
}
