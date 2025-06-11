import React, {useState} from 'react'
import JSONSchemaForm from "~/components/JSONSchemaForm.jsx";
import {v4 as uuidv4} from 'uuid';

const EndpointDiff = ({endpoint, remove, updateName}) => {
    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_url}`}
                </div>
                <div className="endpoint-name">
                    <select
                        name="version[endpoints_attributes][][http_verb]"
                        onChange={(e) => updateName(endpoint.id, e.target.value, endpoint.url)}
                    >
                        {["verb_get", "verb_post", "verb_delete", "verb_put", "verb_patch"].map((verb) => (
                            <option value={verb} selected={endpoint.http_verb === verb}>{verb}</option>
                        ))}
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
                <div className="endpoint-section">INPUT</div>
                <div className="endpoint-section">INPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    {/*< %= render "spec", diff: input_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_input_string]"
                        initialRoot={endpoint.input}
                    />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT</div>
                <div className="endpoint-section">OUTPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    {/*<%= render "spec", diff: output_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_output_string]"
                        initialRoot={endpoint.output}
                    />
                </div>
            </div>
        </div>
    )
}

export default EndpointDiff
