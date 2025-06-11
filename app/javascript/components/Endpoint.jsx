import React from 'react'
import EndpointRemoved from "~/components/EndpointRemoved.jsx";
import EndpointDiff from "~/components/EndpointDiff.jsx";
import EndpointAdded from "~/components/EndpointAdded.jsx";

const Endpoint = ({endpoint, remove, updateName}) => {
    if (endpoint.type === 'removed') {
        return (<EndpointRemoved endpoint={endpoint} remove={remove} updateName={updateName}/>)
    }

    if (endpoint.type === 'new') {
        return (<EndpointAdded endpoint={endpoint} remove={remove} updateName={updateName}/>)
    }

    return (<EndpointDiff endpoint={endpoint} remove={remove} updateName={updateName}/>)

}

export default Endpoint
