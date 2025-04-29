import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "newAttribute"]

    addAttribute() {
        this.newAttributeTarget.before(this.newAttribute(this.inputTarget.value))
        this.inputTarget.value = "new";
    }

    newAttribute(name) {
        const container = document.createElement("div")
        container.className = "endpoint_form_object_attribute"
        container.innerHTML = `<span>${name}</span>: 
          <span data-controller="value" data-value-target="span" data-value="string">  
            <select data-action="value#change root#update">
              <option selected="selected" value="string">string</option>
              <option value="number">number</option>
              <option value="object">object</option>
            </select>
          </span>
          `

        return container;
    }
}
