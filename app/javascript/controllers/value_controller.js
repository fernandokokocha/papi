import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["span", "select"]

    change(event) {
        const oldValue = this.spanTarget.getAttribute("data-value")
        this.spanTarget.setAttribute("data-value", event.target.value)

        if (oldValue === "object") {
            console.log(this.spanTarget.nextElementSibling)
            this.spanTarget.nextElementSibling.remove()
        }

        if (event.target.value === "object") {
            this.spanTarget.after(this.emptyObject())
        }
    }

    emptyObject() {
        const container = document.createElement("div")
        container.className = "endpoint_form_object";
        container.innerHTML = `{ 
          <div data-object-target="newAttribute" class="endpoint_form_object_new_attribute">
            <input data-object-target="input" type="text" value="new" />
            <button data-action="object#addAttribute" type="button">+</button>
          </div>
        }`

        return container;
    }
}
