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

const isNewEntityColliding = (newEntity, entities) => {
    let newEntityColliding = false
    entities.filter((entity) => (entity.type !== 'removed'))
        .forEach((entity) => {
            const collidingWithNewEntity = (entity.name === newEntity)
            if (collidingWithNewEntity) {
                newEntityColliding = true
            }
        })

    return newEntityColliding;
}

const checkEntitiesReferences = (endpoints, entities) => {
    entities.forEach((entity) => {
        entity.is_referenced = findCustomNameInEndpoints(endpoints, entity.name)
    })
}

const findCustomNameInEndpoints = (endpoints, name) => {
    let found = false;
    endpoints.forEach((e) => {
        found = found || findCustomName(e.input, name)
        found = found || findCustomName(e.output, name)
    })
    return found
}

const findCustomName = (root, name) => {
    if (root.nodeType === "custom" && root.value === name) {
        return true;
    }

    if (root.nodeType === 'object') {
        let found = false;
        root.attributes.forEach((oa) => {
            found = found || findCustomName(oa.value, name)
        })
        return found
    }

    if (root.nodeType === 'array') {
        return findCustomName(root.value, name)
    }

    return false;
}

const Form = ({serializedEndpoints, serializedEntities}) => {
    const [entities, setEntities] = useState([]);
    const [endpoints, setEndpoints] = useState([]);
    const [noCollisions, setNoCollisions] = useState(true);
    const [anyChanges, setAnyChanges] = useState(false);
    const [newUrl, setNewUrl] = useState("/resource")
    const [newVerb, setNewVerb] = useState("verb_get")
    const [addEndpointDisabled, setAddEndpointDisabled] = useState(() => isNewEndpointColliding(newVerb, newUrl, endpoints))
    const [newEntity, setNewEntity] = useState("MyResource")
    const [addEntityDisabled, setAddEntityDisabled] = useState(() => isNewEntityColliding(newEntity, entities))

    const validateNewEndpoint = (verb, url, e) => {
        setAddEndpointDisabled(isNewEndpointColliding(verb, url, e))
    }

    const validateNewEntity = (newEntity, entities) => {
        setAddEntityDisabled(isNewEntityColliding(newEntity, entities))
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

    const updateNewEntity = (e) => {
        setNewEntity(e.target.value)
        validateNewEntity(e.target.value, entities)
    }

    const addEntity = () => {
        const newEntities = JSON.parse(JSON.stringify(entities))
        newEntities.push({
            type: "new",
            id: uuidv4(),
            root: deserialize(""),
            original_root: deserialize(""),
            name: newEntity,
            original_name: newEntity,
            collision: false,
            is_referenced: false
        })
        validateNewEntity(newEntity, newEntities)
        setEntities(newEntities)
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
        checkEntitiesReferences(newEndpoints, entities)
    }

    const updateOutput = (id, newOutput) => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToUpdate = newEndpoints.find((endpoint) => (endpoint.id === id))
        endpointToUpdate.output = newOutput

        validate(newEndpoints)
        validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEndpoints(newEndpoints)
        checkEntitiesReferences(newEndpoints, entities)
    }

    const updateEntityRoot = (id, newRoot) => {
        const newEntities = JSON.parse(JSON.stringify(entities))
        const entityToUpdate = newEntities.find((entity) => (entity.id === id))
        entityToUpdate.root = newRoot
        setEntities(newEntities)
    }

    const removeEntity = (id) => {
        let newEntities = JSON.parse(JSON.stringify(entities))
        const entityToRemove = newEntities.find((entity) => (entity.id === id))
        if (entityToRemove.type === 'old') {
            entityToRemove.type = 'removed'
        } else if (entityToRemove.type === 'new') {
            newEntities = newEntities.filter((entity) => (entity.id !== id))
        }

        validateNewEntity(newEntity, newEntities)
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
            entityData.is_referenced = true
        })
        checkEntitiesReferences(parsed_endpoints, parsed_entities)
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
                removeEntity={removeEntity}
                newEntity={newEntity}
                updateNewEntity={updateNewEntity}
                addEntity={addEntity}
                addEntityDisabled={addEntityDisabled}
            />
        </>
    )
}

export default Form
