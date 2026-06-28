import React, {useEffect, useState} from 'react'
import ResponseList from "@/components/ResponseList.jsx";
import {arrayDifference} from "@/helpers/arrayDiffrence.js";
import {httpStatusCodes} from "@/helpers/values.js";
import {verbSelectClass} from "@/helpers/verbColors.js";

const EndpointAdded = ({endpoint, remove, updateEndpoint, entities}) => {
    const updateVerb = (newVerb) => {
        updateEndpoint(endpoint.id, {...endpoint, http_verb: newVerb})
    }

    const updatePath = (newPath) => {
        updateEndpoint(endpoint.id, {...endpoint, path: newPath})
    }

    const updateNote = (newNote) => {
        updateEndpoint(endpoint.id, {...endpoint, note: newNote})
    }

    const addResponse = () => {
        const newResponses = [...endpoint.responses, {code: newResponseCode, note: "", output: {nodeType: "primitive", value: "nothing"}}]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const removeResponse = (code) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            ...endpoint.responses.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const updateResponseNote = (code, newNote) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const r = endpoint.responses[index]
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {...r, note: newNote},
            ...endpoint.responses.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const updateResponseOutput = (code, newOutput) => {
        const index = endpoint.responses.findIndex((r) => r.code === code)
        const r = endpoint.responses[index]
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {...r, output: newOutput},
            ...endpoint.responses.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, responses: newResponses})
    }

    const [responsesToAdd, setResponsesToAdd] = useState([])
    const [newResponseCode, setNewResponseCode] = useState(null)

    useEffect(() => {
        const newResponsesToAdd = arrayDifference(httpStatusCodes, endpoint.responses.map((r) => r.code))
        setResponsesToAdd(newResponsesToAdd)
        setNewResponseCode(newResponsesToAdd[0])
    }, [endpoint])

    return (
        <div className="grid grid-cols-2 gap-2">
            <div></div>
            <div>
                <div className="border border-emerald-200 rounded-lg overflow-hidden">
                    <div className="bg-emerald-700 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                        <select
                            name="version[endpoints_attributes][][http_verb]"
                            value={endpoint.http_verb}
                            onChange={(e) => updateVerb(e.target.value)}
                            className={`text-xs font-bold rounded border px-1 py-0.5 focus:outline-none ${verbSelectClass(endpoint.http_verb)}`}
                        >
                            <option value="verb_get">GET</option>
                            <option value="verb_post">POST</option>
                            <option value="verb_delete">DELETE</option>
                            <option value="verb_put">PUT</option>
                            <option value="verb_patch">PATCH</option>
                        </select>
                        <input
                            type="text"
                            value={endpoint.path}
                            onChange={(e) => updatePath(e.target.value)}
                            name="version[endpoints_attributes][][path]"
                            className="bg-emerald-600 text-white text-xs rounded border border-emerald-500 px-2 py-0.5 flex-1 focus:outline-none"
                        />
                        <button
                            type="button"
                            onClick={() => remove(endpoint.id)}
                            className="text-xs bg-white/10 hover:bg-white/25 text-white px-2 py-0.5 rounded ml-auto shrink-0"
                        >
                            Remove
                        </button>
                        {endpoint.collision && <span className="text-xs text-red-300">Collision!</span>}
                        {endpoint.no_responses && <span className="text-xs text-red-300">Needs a response</span>}
                    </div>
                    <ResponseList
                        endpoint={endpoint}
                        addResponse={addResponse}
                        removeResponse={removeResponse}
                        updateResponseNote={updateResponseNote}
                        updateResponseOutput={updateResponseOutput}
                        updateNote={updateNote}
                        responsesToAdd={responsesToAdd}
                        newResponseCode={newResponseCode}
                        setNewResponseCode={setNewResponseCode}
                        entities={entities}
                        theme="emerald"
                    />
                </div>
            </div>
        </div>
    )
}

export default EndpointAdded
