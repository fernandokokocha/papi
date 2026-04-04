import React, {useEffect, useState} from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";
import {arrayDifference} from "@/helpers/arrayDiffrence.js";
import {httpStatusCodes} from "@/helpers/values.js";

const sectionHeader = "bg-emerald-50 border-t border-emerald-200 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRow = "px-3 py-2 bg-emerald-50 border-b border-emerald-200 text-sm text-gray-700"
const contentRowPl = "pl-2 py-2 bg-emerald-50 border-b border-emerald-200"

const EndpointAdded = ({endpoint, remove, updateEndpoint, entities}) => {
    const updateVerb = (newVerb) => {
        updateEndpoint(endpoint.id, {...endpoint, http_verb: newVerb})
    }

    const updatePath = (newPath) => {
        updateEndpoint(endpoint.id, {...endpoint, path: newPath})
    }

    const updateOutput = (newOutput) => {
        updateEndpoint(endpoint.id, {...endpoint, output: newOutput})
    }

    const updateOutputError = (newOutputError) => {
        updateEndpoint(endpoint.id, {...endpoint, output_error: newOutputError})
    }

    const updateNote = (newNote) => {
        updateEndpoint(endpoint.id, {...endpoint, note: newNote})
    }

    const addResponse = () => {
        const newResponses = [...endpoint.responses, {code: newResponseCode, note: ""}]
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
        const newResponses = [
            ...endpoint.responses.slice(0, index),
            {code, note: newNote},
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
        <div className="grid grid-cols-2 gap-2" key={endpoint.id}>
            <div></div>
            <div>
                <div className="border border-emerald-200 rounded-lg overflow-hidden">
                    <div className="bg-emerald-700 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                        <select
                            name="version[endpoints_attributes][][http_verb]"
                            onChange={(e) => updateVerb(e.target.value)}
                            className="bg-emerald-600 text-white text-xs rounded border border-emerald-500 px-1 focus:outline-none"
                        >
                            <option value="verb_get" selected={endpoint.http_verb === "verb_get"}>GET</option>
                            <option value="verb_post" selected={endpoint.http_verb === "verb_post"}>POST</option>
                            <option value="verb_delete" selected={endpoint.http_verb === "verb_delete"}>DELETE</option>
                            <option value="verb_put" selected={endpoint.http_verb === "verb_put"}>PUT</option>
                            <option value="verb_patch" selected={endpoint.http_verb === "verb_patch"}>PATCH</option>
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
                    </div>
                    <div className={sectionHeader}>Note</div>
                    <div className="px-3 py-2 bg-emerald-50 border-b border-emerald-200">
                        <textarea
                            name="version[endpoints_attributes][][note]"
                            value={endpoint.note}
                            onChange={(e) => updateNote(e.target.value)}
                            rows="3"
                            className="border border-emerald-300 rounded px-2 py-1 text-sm w-full focus:outline-none focus:ring-1 focus:ring-emerald-500 resize-y bg-white"
                        />
                    </div>
                    <div className={sectionHeader}>Responses</div>
                    <div className="pl-2 py-2 bg-emerald-50 border-b border-emerald-200 space-y-1">
                        {endpoint.responses.map((r) => (
                            <div key={r.code} className="flex items-center gap-2">
                                <span className="font-mono text-xs text-gray-500 shrink-0">{r.code}:</span>
                                <input
                                    type="text"
                                    value={r.note}
                                    onChange={(e) => updateResponseNote(r.code, e.target.value)}
                                    className="border border-gray-300 rounded px-2 py-0.5 text-xs flex-1 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white"
                                />
                                <button
                                    type="button"
                                    onClick={() => removeResponse(r.code)}
                                    className="text-xs text-red-500 hover:text-red-700 shrink-0"
                                >×</button>
                                <input
                                    type="hidden"
                                    name={`version[endpoints_attributes][][responses][${r.code}]`}
                                    value={r.note}
                                />
                            </div>
                        ))}
                        <div className="flex items-center gap-2 pt-1">
                            <select
                                onChange={(e) => setNewResponseCode(e.target.value)}
                                className="border border-gray-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white"
                            >
                                {responsesToAdd.map((r) => (
                                    <option key={r} value={r} selected={newResponseCode === r}>{r}</option>
                                ))}
                            </select>
                            <button
                                type="button"
                                onClick={() => addResponse()}
                                className="text-xs bg-emerald-600 hover:bg-emerald-700 text-white px-2 py-0.5 rounded"
                            >
                                Add
                            </button>
                        </div>
                    </div>
                    <div className={sectionHeader}>Output</div>
                    <div className={contentRowPl}>
                        <JSONSchemaForm
                            name="version[endpoints_attributes][][output]"
                            update={updateOutput}
                            root={endpoint.output}
                            id={endpoint.id}
                            entities={entities}
                        />
                    </div>
                    <div className={sectionHeader}>Output for Errors</div>
                    <div className={contentRowPl}>
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
        </div>
    )
}

export default EndpointAdded
