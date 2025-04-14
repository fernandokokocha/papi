import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "newAttribute"]

    addAttribute() {
        this.newAttributeTarget.before(this.newAttribute(this.inputTarget.value))

        this.inputTarget.value = "";
    }

    newAttribute(name) {
        const container = document.createElement("div")
        container.className = "endpoint_form_object_attribute"
        container.innerHTML = `${name}: 
          <span data-controller="value" data-value-target="span" data-value="string">  
            <select name="value" id="value" data-action="value#change">
              <option selected="selected" value="string">string</option>
              <option value="number">number</option>
              <option value="object">object</option>
            </select>
          </span>
          `

        return container;
    }
}
