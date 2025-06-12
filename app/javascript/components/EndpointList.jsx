import React, {useState} from 'react'
import {v4 as uuidv4} from 'uuid';
import Endpoint from "~/components/Endpoint.jsx";

const isNewEndpointColliding = (verb, url, e) => {
    let newEndpointColliding = false
    e.filter((endpoint) => (endpoint.type !== 'removed'))
        .forEach((endpoint) => {
            const collidingWithNewEndpoint = (endpoint.url === url && endpoint.http_verb === verb)
            if (collidingWithNewEndpoint) {
                newEndpointColliding = true
            }
        })

    return newEndpointColliding;
}

const EndpointList = ({serializedEndpoints}) => {
    const parsed = JSON.parse(serializedEndpoints)
    parsed.forEach((endpointData) => {
        endpointData.type = "old"
        endpointData.id = uuidv4()
        endpointData.original_url = endpointData.url
        endpointData.original_verb = endpointData.verb
        endpointData.collision = false
    })

    const [endpoints, setEndpoints] = useState(parsed);
    const [noCollisions, setNoCollisions] = useState(true);
    const [anyChanges, setAnyChanges] = useState(false);
    const [newUrl, setNewUrl] = useState("/resource")
    const [newVerb, setNewVerb] = useState("verb_get")
    const [addEndpointDisabled, setAddEndpointDisabled] = useState(() => isNewEndpointColliding(newVerb, newUrl, endpoints))

    const validateNewEndpoint = (verb, url, e) => {
        setAddEndpointDisabled(isNewEndpointColliding(verb, url, e))
    }

    const validate = (newEndpoints) => {
        let newNoCollisions = true;
        newEndpoints
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .forEach((endpoint) => {
                const colliding = newEndpoints.filter((otherEndpoint) => otherEndpoint.url === endpoint.url && otherEndpoint.http_verb === endpoint.http_verb)
                if (colliding.length > 1) {
                    newNoCollisions = false;
                    endpoint.collision = true;
                } else {
                    endpoint.collision = false;
                }
            })
        setNoCollisions(newNoCollisions)

        const serialized = JSON.stringify(newEndpoints
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .map((endpoint) => ({
                http_verb: endpoint.http_verb,
                verb: endpoint.verb,
                url: endpoint.url,
                input: endpoint.input,
                output: endpoint.output,
                page_url: endpoint.page_url
            })))
        const newAnyChanges = serialized !== serializedEndpoints
        setAnyChanges(newAnyChanges)
    }

    const updateEndpoint = (id, updatedVerb, updatedUrl) => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToUpdate = newEndpoints.find((endpoint) => (endpoint.id === id))
        endpointToUpdate.http_verb = updatedVerb
        endpointToUpdate.url = updatedUrl

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
    }

    const removeEndpoint = (id) => {
        let newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToRemove = newEndpoints.find((endpoint) => (endpoint.id === id))
        if (endpointToRemove.type === 'old') {
            endpointToRemove.type = 'removed'
        } else if (endpointToRemove.type === 'new') {
            newEndpoints = newEndpoints.filter((endpoint) => (endpoint.id !== id))
        }

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
    }

    const addEndpoint = () => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        newEndpoints.push({
            id: uuidv4(),
            type: "new",
            http_verb: newVerb,
            verb: newVerb,
            url: newUrl,
            input: "",
            output: "",
            page_url: `${newVerb}-${newUrl}`
        })

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
    }

    const updateNewUrl = (e) => {
        setNewUrl(e.target.value)
        validateNewEndpoint(newVerb, e.target.value, endpoints)
    }

    const updateNewVerb = (e) => {
        setNewVerb(e.target.value)
        validateNewEndpoint(e.target.value, newUrl, endpoints)
    }

    const updateInput = (id, newInput) => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToUpdate = newEndpoints.find((endpoint) => (endpoint.id === id))
        endpointToUpdate.input = newInput

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
    }

    const updateOutput = (id, newOutput) => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToUpdate = newEndpoints.find((endpoint) => (endpoint.id === id))
        endpointToUpdate.output = newOutput

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
    }

    return (
        <div>
            <div className="submit">
                {!noCollisions && <div className="alert">Resolve collisions</div>}
                {!anyChanges && <div className="alert">Make any changes</div>}
                <input type="submit" name="commit" value="Create Version" disabled={!(noCollisions && anyChanges)}/>
            </div>

            {endpoints.map((endpoint) => (
                <Endpoint
                    endpoint={endpoint}
                    remove={removeEndpoint}
                    updateName={updateEndpoint}
                    updateInput={updateInput}
                    updateOutput={updateOutput}
                />
            ))}

            <div className="endpoint-container">
                <div className="endpoint-name-container">
                    <div className="endpoint-name-placeholder"></div>
                    <div className="endpoint-name added">
                        <select onChange={updateNewVerb}>
                            {["verb_get", "verb_post", "verb_delete", "verb_put", "verb_patch"].map((verb) => (
                                <option value={verb} selected={newVerb === verb}>{verb}</option>
                            ))}
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
