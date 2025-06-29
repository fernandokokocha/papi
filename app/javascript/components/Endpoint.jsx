import React from 'react'
import EndpointRemoved from "~/components/EndpointRemoved.jsx";
import EndpointDiff from "~/components/EndpointDiff.jsx";
import EndpointAdded from "~/components/EndpointAdded.jsx";

const Endpoint = ({endpoint, remove, updateEndpoint, entities}) => {
    if (endpoint.type === 'removed') {
        return (<EndpointRemoved
            endpoint={endpoint}
            remove={remove}
            updateEndpoint={updateEndpoint}
            entities={entities}
        />)
    }

    if (endpoint.type === 'new') {
        return (<EndpointAdded
            endpoint={endpoint}
            remove={remove}
            updateEndpoint={updateEndpoint}
            entities={entities}
        />)
    }

    return (<EndpointDiff
        endpoint={endpoint}
        remove={remove}
        updateEndpoint={updateEndpoint}
        entities={entities}
    />)
}

export default Endpoint
