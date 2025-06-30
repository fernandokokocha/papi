import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import serialize from "@/helpers/serialize.js";

const EndpointDiff = ({endpoint, remove, updateEndpoint, entities}) => {
    const updateVerb = (newVerb) => {
        const newEndpoint = {
            ...endpoint,
            http_verb: newVerb
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateUrl = (newUrl) => {
        const newEndpoint = {
            ...endpoint,
            url: newUrl
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateInput = (newInput) => {
        const newEndpoint = {
            ...endpoint,
            input: newInput
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateOutput = (newOutput) => {
        const newEndpoint = {
            ...endpoint,
            output: newOutput
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateNote = (newNote) => {
        const newEndpoint = {
            ...endpoint,
            note: newNote
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_url}`}
                </div>
                <div className="endpoint-name">
                    <div>
                        <select
                            name="version[endpoints_attributes][][http_verb]"
                            onChange={(e) => updateVerb(e.target.value)}
                        >
                            <option value="verb_get" selected={endpoint.http_verb === "verb_get"}>GET</option>
                            <option value="verb_post" selected={endpoint.http_verb === "verb_post"}>POST</option>
                            <option value="verb_delete" selected={endpoint.http_verb === "verb_delete"}>DELETE</option>
                            <option value="verb_put" selected={endpoint.http_verb === "verb_put"}>PUT</option>
                            <option value="verb_patch" selected={endpoint.http_verb === "verb_patch"}>PATCH</option>
                        </select>
                        <input type="text"
                               value={endpoint.url}
                               onChange={(e) => updateUrl(e.target.value)}
                               name="version[endpoints_attributes][][url]"
                        />
                    </div>
                    <button type="button" onClick={(e) => remove(endpoint.id)}>x</button>
                    {endpoint.collision && <div className="alert">Colliding endpoint</div>}
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">NOTE</div>
                <div className="endpoint-section">NOTE</div>
            </div>

            <div className="endpoint-note-container">
                <div className="endpoint-note">{endpoint.original_note}</div>
                <div className="endpoint-note">
                    <textarea
                        name="version[endpoints_attributes][][note]"
                        value={endpoint.note}
                        onChange={(e) => updateNote(e.target.value)}
                        rows="5"
                        cols="50"
                        wrap="hard"
                    />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">INPUT</div>
                <div className="endpoint-section">INPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.original_input}/>
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_input_string]"
                        update={updateInput}
                        root={endpoint.input}
                        id={endpoint.id}
                        entities={entities}
                    />
                </div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.original_input)}</div>
                </div>
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.input)}</div>
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT</div>
                <div className="endpoint-section">OUTPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.original_output}/>
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][original_output_string]"
                        update={updateOutput}
                        root={endpoint.output}
                        id={endpoint.id}
                        entities={entities}
                    />
                </div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.original_output)}</div>
                </div>
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.output)}</div>
                </div>
            </div>
        </div>
    )
}

export default EndpointDiff
