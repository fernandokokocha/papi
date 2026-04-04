import React from 'react'
import Endpoint from "~/components/Endpoint.jsx";

const EndpointList = ({
                          endpoints,
                          entities,
                          removeEndpoint,
                          updateEndpoint,
                          addEndpoint,
                          updateNewVerb,
                          newVerb,
                          newPath,
                          updateNewPath,
                          addEndpointDisabled,
                      }) => {

    return (
        <>
            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-6">Endpoints</div>

            <div className="flex flex-col gap-6">
                {endpoints.map((endpoint) => (
                    <Endpoint
                        key={endpoint.id}
                        endpoint={endpoint}
                        remove={removeEndpoint}
                        updateEndpoint={updateEndpoint}
                        entities={entities}
                    />
                ))}
            </div>

            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-8">Add Endpoint</div>

            <div className="grid grid-cols-2 gap-2">
                <div></div>
                <div>
                    <div className="border border-emerald-200 rounded-lg overflow-hidden">
                        <div className="bg-emerald-700 text-white px-4 py-3 text-sm font-mono flex items-center gap-2 flex-wrap">
                            <select
                                onChange={updateNewVerb}
                                className="bg-emerald-600 text-white text-xs rounded border border-emerald-500 px-1 py-0.5 focus:outline-none"
                            >
                                <option value="verb_get" selected={newVerb === "verb_get"}>GET</option>
                                <option value="verb_post" selected={newVerb === "verb_post"}>POST</option>
                                <option value="verb_delete" selected={newVerb === "verb_delete"}>DELETE</option>
                                <option value="verb_put" selected={newVerb === "verb_put"}>PUT</option>
                                <option value="verb_patch" selected={newVerb === "verb_patch"}>PATCH</option>
                            </select>
                            <input
                                type="text"
                                value={newPath}
                                onChange={updateNewPath}
                                className="bg-emerald-600 text-white placeholder-emerald-300 text-xs rounded border border-emerald-500 px-2 py-0.5 flex-1 focus:outline-none"
                            />
                            <button
                                type="button"
                                onClick={addEndpoint}
                                disabled={addEndpointDisabled}
                                className={addEndpointDisabled
                                    ? "text-xs bg-white/20 text-white/50 px-3 py-1 rounded cursor-not-allowed"
                                    : "text-xs bg-white text-emerald-700 hover:bg-emerald-50 px-3 py-1 rounded cursor-pointer font-medium"}
                            >
                                Add
                            </button>
                        </div>
                        {addEndpointDisabled && (
                            <div className="px-3 py-2 bg-emerald-50 text-xs text-red-600 border-t border-emerald-200">
                                This endpoint already exists
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </>
    )
}

export default EndpointList
