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
                          newUrl,
                          updateNewUrl,
                          addEndpointDisabled,
                          updateInput,
                          updateOutput
                      }) => {

    return (
        <div>
            <div className="section">Endpoints</div>

            {endpoints.map((endpoint) => (
                <Endpoint
                    endpoint={endpoint}
                    remove={removeEndpoint}
                    updateName={updateEndpoint}
                    updateInput={updateInput}
                    updateOutput={updateOutput}
                    entities={entities}
                />
            ))}

            <div className="endpoint-container added">
                <div className="endpoint-name-container">
                    <div className="endpoint-name-placeholder"></div>
                    <div className="endpoint-name added">
                        <select onChange={updateNewVerb}>
                            <option value="verb_get" selected={newVerb === "verb_get"}>GET</option>
                            <option value="verb_post" selected={newVerb === "verb_post"}>POST</option>
                            <option value="verb_delete" selected={newVerb === "verb_delete"}>DELETE</option>
                            <option value="verb_put" selected={newVerb === "verb_put"}>PUT</option>
                            <option value="verb_patch" selected={newVerb === "verb_patch"}>PATCH</option>
                        </select>
                        <input type="text" value={newUrl} onChange={updateNewUrl}/>
                        <button type="button" onClick={addEndpoint} disabled={addEndpointDisabled}>Add</button>
                        {addEndpointDisabled && <div className="alert">This endpoint already exists</div>}
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EndpointList
