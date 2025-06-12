import React from 'react'
import EndpointRemoved from "~/components/EndpointRemoved.jsx";
import EndpointDiff from "~/components/EndpointDiff.jsx";
import EndpointAdded from "~/components/EndpointAdded.jsx";

const Endpoint = ({endpoint, remove, updateName, updateInput, updateOutput}) => {
    if (endpoint.type === 'removed') {
        return (<EndpointRemoved
            endpoint={endpoint}
            remove={remove}
            updateName={updateName}
            updateInput={updateInput}
            updateOutput={updateOutput}
        />)
    }

    if (endpoint.type === 'new') {
        return (<EndpointAdded
            endpoint={endpoint}
            remove={remove}
            updateName={updateName}
            updateInput={updateInput}
            updateOutput={updateOutput}
        />)
    }

    return (<EndpointDiff
        endpoint={endpoint}
        remove={remove}
        updateName={updateName}
        updateInput={updateInput}
        updateOutput={updateOutput}
    />)

}

export default Endpoint
