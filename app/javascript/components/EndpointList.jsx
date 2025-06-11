import React, {useState} from 'react'
import {v4 as uuidv4} from 'uuid';
import Endpoint from "~/components/Endpoint.jsx";

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
    const [newVerb, setNewVerb] = useState("http_get")

    const validateSubmit = (newEndpoints) => {
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

    const updateName = (id, newVerb, newUrl) => {
        const newWitam = JSON.parse(JSON.stringify(endpoints))
        const endpointToUpdate = newWitam.find((endpoint) => (endpoint.id === id))
        endpointToUpdate.http_verb = newVerb
        endpointToUpdate.url = newUrl

        validateSubmit(newWitam)
        setEndpoints(newWitam)
    }

    const remove = (id) => {
        let newWitam = JSON.parse(JSON.stringify(endpoints))
        const endpointToRemove = newWitam.find((endpoint) => (endpoint.id === id))
        if (endpointToRemove.type === 'old') {
            endpointToRemove.type = 'removed'
        } else if (endpointToRemove.type === 'new') {
            newWitam = newWitam.filter((endpoint) => (endpoint.id !== id))
        }

        validateSubmit(newWitam)
        setEndpoints(newWitam)
    }

    const add = () => {
        const newWitam = JSON.parse(JSON.stringify(endpoints))
        newWitam.push({
            id: uuidv4(),
            type: "new",
            http_verb: newVerb,
            verb: newVerb,
            url: newUrl,
            input: "",
            output: "",
            page_url: `${newVerb}-${newUrl}`
        })

        validateSubmit(newWitam)
        setEndpoints(newWitam)
    }

    return (
        <div>
            <div className="submit">
                {!noCollisions && <div className="alert">Resolve collisions</div>}
                {!anyChanges && <div className="alert">Make any changes</div>}
                <input type="submit" name="commit" value="Create Version" disabled={!(noCollisions && anyChanges)}/>
            </div>

            {endpoints.map((endpoint) => (
                <Endpoint endpoint={endpoint} remove={remove} updateName={updateName}/>
            ))}

            <div className="endpoint-container">
                <div className="endpoint-name-container">
                    <div className="endpoint-name-placeholder"></div>
                    <div className="endpoint-name added">
                        <select onChange={(e) => {
                            setNewVerb(e.target.value)
                        }}>
                            {["verb_get", "verb_post", "verb_delete", "verb_put", "verb_patch"].map((verb) => (
                                <option value={verb} selected={newVerb === verb}>{verb}</option>
                            ))}
                        </select>
                        <input type="text" value={newUrl} onChange={(e) => {
                            setNewUrl(e.target.value)
                        }}/>
                        <button type="button" onClick={add}>Add</button>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EndpointList
