import React from 'react'
import EndpointRemoved from "~/components/EndpointRemoved.jsx";
import EndpointDiff from "~/components/EndpointDiff.jsx";
import EndpointAdded from "~/components/EndpointAdded.jsx";

const Endpoint = ({endpoint, remove, updateName, updateInput, updateOutput, entities}) => {
    if (endpoint.type === 'removed') {
        return (<EndpointRemoved
            endpoint={endpoint}
            remove={remove}
            updateName={updateName}
            updateInput={updateInput}
            updateOutput={updateOutput}
            entities={entities}
        />)
    }

    if (endpoint.type === 'new') {
        return (<EndpointAdded
            endpoint={endpoint}
            remove={remove}
            updateName={updateName}
            updateInput={updateInput}
            updateOutput={updateOutput}
            entities={entities}
        />)
    }

    return (<EndpointDiff
        endpoint={endpoint}
        remove={remove}
        updateName={updateName}
        updateInput={updateInput}
        updateOutput={updateOutput}
        entities={entities}
    />)

}

export default Endpoint
