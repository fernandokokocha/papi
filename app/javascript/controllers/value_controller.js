import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["span", "select"]

    change(event) {
        console.log("change");
        console.log(this.spanTarget);
        const oldValue = this.spanTarget.getAttribute("data-value")
        this.spanTarget.setAttribute("data-value", event.target.value)

        if (oldValue === "object") {
            this.spanTarget.nextElementSibling.nextElementSibling.remove()
        }

        if (event.target.value === "object") {
            this.spanTarget.after(this.emptyObject())
            this.spanTarget.after(this.closeButton())
        }
    }

    emptyObject() {
        const container = document.createElement("div")
        container.className = "endpoint_form_object";
        container.setAttribute("data-controller", "object")
        container.innerHTML = `{ 
          <div data-object-target="newAttribute" class="endpoint_form_object_new_attribute">
            <input data-object-target="input" type="text" value="new" />
            <button data-action="object#addAttribute root#update" type="button">+</button>
          </div>
        }`

        return container;
    }

    closeButton() {
        const button = document.createElement("button")
        button.setAttribute("type", "button")
        button.setAttribute("data-action", "root#removeAttribute")
        button.innerText = "x";

        return button;
    }
}
