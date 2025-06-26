import React, {useEffect, useState} from 'react'
import EndpointList from "@/components/EndpointList.jsx";
import EntityList from "@/components/EntityList.jsx";
import {v4 as uuidv4} from "uuid";
import deserialize from "@/helpers/deserialize.js";

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

const updateNewEntityName = (root, oldName, newName) => {
    console.log('updateNewEntityName', {oldName, newName})
    if (root.nodeType === "custom" && root.value === oldName) {
        root.value = newName
    }

    if (root.nodeType === 'object') {
        root.attributes.forEach((oa) => {
            updateNewEntityName(oa.value, oldName, newName)
        })
    }

    if (root.nodeType === 'array') {
        updateNewEntityName(root.value, oldName, newName)
    }
}

const Form = ({serializedEndpoints, serializedEntities}) => {
    const [entities, setEntities] = useState([]);
    const [endpoints, setEndpoints] = useState([]);
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
                output: endpoint.output
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
            output: ""
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

    const updateEntityRoot = (id, newRoot) => {
        const newEntities = JSON.parse(JSON.stringify(entities))
        const entityToUpdate = newEntities.find((entity) => (entity.id === id))
        entityToUpdate.root = newRoot
        setEntities(newEntities)
    }

    useEffect(() => {
        const parsed_endpoints = JSON.parse(serializedEndpoints)
        parsed_endpoints.forEach((endpointData) => {
            endpointData.type = "old"
            endpointData.id = uuidv4()
            endpointData.original_url = endpointData.url
            endpointData.original_verb = endpointData.verb
            const parsed_input = deserialize(endpointData.input)
            endpointData.original_input = parsed_input
            endpointData.input = parsed_input
            const parsed_output = deserialize(endpointData.output)
            endpointData.original_output = parsed_output
            endpointData.output = parsed_output
            endpointData.collision = false
        })
        setEndpoints(parsed_endpoints)

        const parsed_entities = JSON.parse(serializedEntities)
        parsed_entities.forEach((entityData) => {
            entityData.type = "old"
            entityData.id = uuidv4()
            const parsed_root = deserialize(entityData.root)
            entityData.root = parsed_root
            entityData.original_root = parsed_root
            entityData.original_name = entityData.name
            entityData.collision = false
        })
        setEntities(parsed_entities)
    }, [])

    return (
        <>
            <div className="submit">
                {!noCollisions && <div className="alert">Resolve collisions</div>}
                {!anyChanges && <div className="alert">Make any changes</div>}
                <input type="submit"
                       name="commit"
                       value="Create Version"
                       disabled={!(noCollisions && anyChanges)}
                />
            </div>
            <EndpointList
                serializedEndpoints={serializedEndpoints}
                entities={entities}
                endpoints={endpoints}
                removeEndpoint={removeEndpoint}
                updateEndpoint={updateEndpoint}
                addEndpoint={addEndpoint}
                updateNewVerb={updateNewVerb}
                newVerb={newVerb}
                newUrl={newUrl}
                updateNewUrl={updateNewUrl}
                addEndpointDisabled={addEndpointDisabled}
                updateInput={updateInput}
                updateOutput={updateOutput}
            />
            <EntityList
                entities={entities}
                updateRoot={updateEntityRoot}
                updateName={updateEntityName}
            />
        </>
    )
}

export default Form
