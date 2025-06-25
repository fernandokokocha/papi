import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const EndpointAdded = ({endpoint, remove, updateName, updateInput, updateOutput}) => {
    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name-placeholder">
                </div>
                <div className="endpoint-name added">
                    <select
                        name="version[endpoints_attributes][][http_verb]"
                        onChange={(e) => updateName(endpoint.id, e.target.value, endpoint.url)}
                    >
                        <option value="verb_get" selected={endpoint.http_verb === "verb_get"}>GET</option>
                        <option value="verb_post" selected={endpoint.http_verb === "verb_post"}>POST</option>
                        <option value="verb_delete" selected={endpoint.http_verb === "verb_delete"}>DELETE</option>
                        <option value="verb_put" selected={endpoint.http_verb === "verb_put"}>PUT</option>
                        <option value="verb_patch" selected={endpoint.http_verb === "verb_patch"}>PATCH</option>
                    </select>
                    <input type="text"
                           value={endpoint.url}
                           onChange={(e) => updateName(endpoint.id, endpoint.http_verb, e.target.value)}
                           name="version[endpoints_attributes][][url]"
                    />
                    <button type="button" onClick={(e) => remove(endpoint.id)}>x</button>
                    {endpoint.collision && <div className="alert">Colliding endpoint</div>}
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section-placeholder"></div>
                <div className="endpoint-section">INPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root-placeholder">
                    {/*< %= render "spec", diff: input_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_input_string]"
                        update={updateInput}
                        root={endpoint.input}
                        id={endpoint.id}
                    />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section-placeholder">OUTPUT</div>
                <div className="endpoint-section">OUTPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root-placeholder">
                    {/*<%= render "spec", diff: output_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_output_string]"
                        update={updateOutput}
                        root={endpoint.output}
                        id={endpoint.id}
                    />
                </div>
            </div>
        </div>
    )
}

export default EndpointAdded
