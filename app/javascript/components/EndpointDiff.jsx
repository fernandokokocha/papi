import React, {useEffect, useState} from 'react'
import EndpointFields from "@/components/EndpointFields.jsx";
import StaticEndpointFields from "@/components/StaticEndpointFields.jsx";
import {arrayDifference} from "@/helpers/arrayDiffrence.js";
import {httpStatusCodes} from "@/helpers/values.js";
import VerbBadge from "@/components/VerbBadge.jsx";
import {verbSelectClass} from "@/helpers/verbColors.js";
import {paramsOf} from "@/helpers/pathParams.js";

const sectionHeader = "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRow = "px-3 py-2 bg-white border-b border-gray-200 text-sm text-gray-700"

const EndpointDiff = ({endpoint, remove, updateEndpoint, entities}) => {
    const updateVerb = (newVerb) => {
        updateEndpoint(endpoint.id, {...endpoint, http_verb: newVerb})
    }

    const updatePath = (newPath) => {
        updateEndpoint(endpoint.id, {...endpoint, path: newPath})
    }

    const updateNote = (newNote) => {
        updateEndpoint(endpoint.id, {...endpoint, note: newNote})
    }

    const updateInput = (newInput) => {
        updateEndpoint(endpoint.id, {...endpoint, input: newInput})
    }

    const addQueryParam = () => {
        updateEndpoint(endpoint.id, {...endpoint, queryParams: [...endpoint.queryParams, {name: "", kind: "string", required: false}]})
    }

    const removeQueryParam = (index) => {
        const newParams = [
            ...endpoint.queryParams.slice(0, index),
            ...endpoint.queryParams.slice(index + 1),
        ]
        updateEndpoint(endpoint.id, {...endpoint, queryParams: newParams})
    }

    const updateQueryParam = (index, param) => {
        const newParams = [...endpoint.queryParams]
        newParams[index] = param
        updateEndpoint(endpoint.id, {...endpoint, queryParams: newParams})
    }

    const updateParamKind = (name, newKind) => {
        updateEndpoint(endpoint.id, {...endpoint, paramKinds: {...endpoint.paramKinds, [name]: newKind}})
    }

    const originalParams = paramsOf(endpoint.original_path, endpoint.original_paramKinds)
    const showParams = originalParams.length > 0 || paramsOf(endpoint.path, endpoint.paramKinds).length > 0

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
        <div className="endpoint-diff">
            {/* Left — original read-only */}
            <div className="endpoint-diff-card border border-gray-200 rounded-lg overflow-hidden">
                <div className="bg-sky-900 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                    <VerbBadge verb={endpoint.original_verb}/>
                    <span className="truncate">{endpoint.original_path}</span>
                </div>
                {showParams && (
                    <>
                        <div className={sectionHeader}>Params</div>
                        <div className="px-3 py-2 bg-white border-b border-gray-200 font-mono text-xs text-gray-800">
                            {originalParams.length === 0 && <span className="text-xs text-gray-400 italic">—</span>}
                            {originalParams.map((p) => (
                                <div key={p.name} className="flex gap-2">
                                    <span className="w-40 shrink-0 truncate">:{p.name}</span>
                                    <span className={`primitive ${p.kind}`}>{p.kind}</span>
                                </div>
                            ))}
                        </div>
                    </>
                )}
                <div className={sectionHeader}>Query</div>
                <div className="px-3 py-2 bg-white border-b border-gray-200 font-mono text-xs text-gray-800">
                    {endpoint.original_queryParams.length === 0 && <span className="text-xs text-gray-400 italic">—</span>}
                    {endpoint.original_queryParams.map((p) => (
                        <div key={p.name} className="flex gap-2">
                            <span className="w-40 shrink-0 truncate">{p.required ? p.name : `${p.name}?`}</span>
                            <span className={`primitive ${p.kind}`}>{p.kind}</span>
                        </div>
                    ))}
                </div>
                <div className={sectionHeader}>Note</div>
                <div className={contentRow}>{endpoint.original_note || <span className="text-gray-400 italic">—</span>}</div>
                <StaticEndpointFields input={endpoint.original_input} responses={endpoint.original_responses}/>
            </div>

            {/* Right — editable */}
            <div className="endpoint-diff-card border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-sky-900 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
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
                            className="bg-sky-800 text-white text-xs rounded border border-sky-600 px-2 py-0.5 flex-1 focus:outline-none"
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
                        {endpoint.duplicate_params && <span className="text-xs text-red-300">Duplicate param</span>}
                        {endpoint.bad_query_params && <span className="text-xs text-red-300">Bad query param</span>}
                    </div>
                    <EndpointFields
                        endpoint={endpoint}
                        addResponse={addResponse}
                        removeResponse={removeResponse}
                        updateResponseNote={updateResponseNote}
                        updateResponseOutput={updateResponseOutput}
                        updateNote={updateNote}
                        updateInput={updateInput}
                        updateParamKind={updateParamKind}
                        addQueryParam={addQueryParam}
                        removeQueryParam={removeQueryParam}
                        updateQueryParam={updateQueryParam}
                        showParams={showParams}
                        responsesToAdd={responsesToAdd}
                        newResponseCode={newResponseCode}
                        setNewResponseCode={setNewResponseCode}
                        entities={entities}
                        theme="sky"
                    />
            </div>
        </div>
    )
}

export default EndpointDiff
