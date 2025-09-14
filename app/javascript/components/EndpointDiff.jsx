import React, {useEffect, useState} from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import serialize from "@/helpers/serialize.js";
import {arrayDifference} from "@/helpers/arrayDiffrence.js";
import {httpStatusCodes} from "@/helpers/values.js";

const EndpointDiff = ({endpoint, remove, updateEndpoint, entities}) => {
    const updateVerb = (newVerb) => {
        const newEndpoint = {
            ...endpoint,
            http_verb: newVerb
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateUrl = (newPath) => {
        const newEndpoint = {
            ...endpoint,
            url: newPath
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

    const updateOutputError = (newOutputError) => {
        const newEndpoint = {
            ...endpoint,
            output_error: newOutputError
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

    const addResponse = () => {
        const newResponses = [...endpoint.responses, {code: newResponseCode, note: ""}]
        const newEndpoint = {
            ...endpoint,
            responses: newResponses
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const removeResponse = (code) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            ...endpoint.responses.slice(index + 1),

        ]
        const newEndpoint = {
            ...endpoint,
            responses: newResponses
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const updateResponseNote = (code, newNote) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {code, note: newNote},
            ...endpoint.responses.slice(index + 1),
        ]
        const newEndpoint = {
            ...endpoint,
            responses: newResponses
        }
        updateEndpoint(endpoint.id, newEndpoint)
    }

    const [responsesToAdd, setResponsesToAdd] = useState([])
    const [newResponseCode, setNewResponseCode] = useState(null)

    useEffect(() => {
        const newResponsesToAdd = arrayDifference(
            httpStatusCodes,
            endpoint.responses.map((r) => r.code)
        )
        setResponsesToAdd(newResponsesToAdd)
        setNewResponseCode(newResponsesToAdd[0])
    }, [endpoint])

    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_path}`}
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
                               value={endpoint.path}
                               onChange={(e) => updateUrl(e.target.value)}
                               name="version[endpoints_attributes][][path]"
                        />
                        {/*<input type="hidden" value={endpoint.id} name="version[endpoints_attributes][][id]" />*/}
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
                <div className="endpoint-section">RESPONSES</div>
                <div className="endpoint-section">RESPONSES</div>
            </div>

            <div className="endpoint-responses-container">
                <div className="endpoint-responses">
                    <div>
                        {endpoint.original_responses.map((r) => (
                            <div>
                                <span className="line">{r.code}</span>:
                                <span className="">{r.note}</span>
                            </div>
                        ))}
                    </div>
                </div>
                <div className="endpoint-responses">
                    <div>
                        {endpoint.responses.map((r) => (
                            <div>
                                <span className="line">{r.code}</span>:
                                <input type="text"
                                       value={r.note}
                                       onChange={(e) => updateResponseNote(r.code, e.target.value)}/>
                                <button type="button" onClick={(e) => removeResponse(r.code)}>x</button>
                                <input
                                    type="hidden"
                                    name={`version[endpoints_attributes][][responses][${r.code}]`}
                                    value={r.note}
                                />
                            </div>
                        ))}
                        <div>
                            <select onChange={(e) => setNewResponseCode(e.target.value)}>
                                {responsesToAdd.map((r) => (
                                    <option value={r} selected={newResponseCode === r}>{r}</option>
                                ))}
                            </select>
                            <button type="button" onClick={() => addResponse()}>Add response</button>
                        </div>
                    </div>
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
                        name="version[endpoints_attributes][][output]"
                        update={updateOutput}
                        root={endpoint.output}
                        id={endpoint.id}
                        entities={entities}
                    />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT FOR ERRORS</div>
                <div className="endpoint-section">OUTPUT FOR ERRORS</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.original_output_error}/>
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name="version[endpoints_attributes][][output_error]"
                        update={updateOutputError}
                        root={endpoint.output_error}
                        id={endpoint.id}
                        entities={entities}
                    />
                </div>
            </div>
        </div>
    )
}

export default EndpointDiff
