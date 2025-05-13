import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["container", "nameholder", "verb", "url", "body"]

    add() {
        const clone = this.containerTarget.cloneNode(true);
        this.containerTarget.after(clone);
        const verbConverted = `verb_${this.verbTarget.value.toLowerCase()}`;
        this.nameholderTarget.innerHTML = `
            <th>
                <input value="${verbConverted}" name="version[endpoints_attributes][][http_verb]" autocomplete="off" type="hidden" id="version_http_verb">
                <input value="${this.urlTarget.value}" name="version[endpoints_attributes][][url]" autocomplete="off" type="hidden" id="version_url">
                ${this.verbTarget.value + " " + this.urlTarget.value}
            </th>`

        this.bodyTarget.innerHTML = this.emptyObject()
    }

    remove(event) {
        const layoutTD = event.target.parentElement.parentElement.parentElement.parentElement.parentElement.parentElement
        layoutTD.innerHTML = ''
    }

    emptyObject() {
        return `
            <tr>
                  <td>
                    <div data-controller="root">
                      <input value="{}" data-root-target="endpointRoot" name="version[endpoints_attributes][][original_endpoint_root]" autocomplete="off" type="hidden" id="version_endpoint_root">
                      <div data-controller="object" class="endpoint_form_object">
                          {
                          <div data-object-target="newAttribute" class="endpoint_form_object_new_attribute">
                            <input data-object-target="input" type="text" value="new">
                            <button data-action="object#addAttribute root#update" type="button">+</button>
                          </div>
                          }
                        </div>
                    </div>
                </td>
            </tr>
`
    }
}
