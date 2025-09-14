import React, {useEffect, useState} from 'react'
import EndpointList from "@/components/EndpointList.jsx";
import EntityList from "@/components/EntityList.jsx";
import {v4 as uuidv4} from "uuid";
import deserialize from "@/helpers/deserialize.js";
import serialize from "@/helpers/serialize.js";

const isNewEndpointColliding = (verb, path, e) => {
    let newEndpointColliding = false
    e.filter((endpoint) => (endpoint.type !== 'removed'))
        .forEach((endpoint) => {
            const collidingWithNewEndpoint = (endpoint.path === path && endpoint.http_verb === verb)
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
        found = found || findCustomName(e.output, name)
        found = found || findCustomName(e.output_error, name)
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
    const [newPath, setNewPath] = useState("/resource")
    const [newVerb, setNewVerb] = useState("verb_get")
    const [addEndpointDisabled, setAddEndpointDisabled] = useState(() => isNewEndpointColliding(newVerb, newPath, endpoints))
    const [newEntity, setNewEntity] = useState("MyResource")
    const [addEntityDisabled, setAddEntityDisabled] = useState(() => isNewEntityColliding(newEntity, entities))

    const validateNewEndpoint = (verb, path, e) => {
        setAddEndpointDisabled(isNewEndpointColliding(verb, path, e))
    }

    const validateNewEntity = (newEntity, entities) => {
        setAddEntityDisabled(isNewEntityColliding(newEntity, entities))
    }

    const validate = (endpointsToSend, entitiesToSend) => {
        let newNoCollisions = true;
        endpointsToSend
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .forEach((endpoint) => {
                const colliding = endpointsToSend.filter((otherEndpoint) => otherEndpoint.path === endpoint.path && otherEndpoint.http_verb === endpoint.http_verb)
                if (colliding.length > 1) {
                    newNoCollisions = false;
                    endpoint.collision = true;
                } else {
                    endpoint.collision = false;
                }
            })
        setNoCollisions(newNoCollisions)

        const serializedEndpointsToSend = JSON.stringify(endpointsToSend
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .map((endpoint) => ({
                http_verb: endpoint.http_verb,
                verb: endpoint.verb,
                path: endpoint.path,
                output: serialize(endpoint.output),
                output_error: serialize(endpoint.output_error),
                note: endpoint.note,
            })))

        if (serializedEndpointsToSend !== serializedEndpoints) {
            setAnyChanges(true)
            return
        }

        const serializedEntitiesToSend = JSON.stringify(entitiesToSend
            .filter((entity) => (entity.type !== 'removed'))
            .map((entity) => ({
                name: entity.name,
                root: serialize(entity.root)
            })))
        if (serializedEntitiesToSend !== serializedEntities) {
            setAnyChanges(true)
            return
        }

        setAnyChanges(false)
    }

    const updateEndpoint = (id, newEndpoint) => {
        const indexToUpdate = endpoints.findIndex((endpoint) => (endpoint.id === id))
        const newEndpoints = [
            ...endpoints.slice(0, indexToUpdate),
            newEndpoint,
            ...endpoints.slice(indexToUpdate + 1),
        ]

        validate(newEndpoints, entities)
        validateNewEndpoint(newVerb, newPath, newEndpoints)
        setEndpoints(newEndpoints)
        checkEntitiesReferences(newEndpoints, entities)
    }

    const removeEndpoint = (id) => {
        let newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToRemove = newEndpoints.find((endpoint) => (endpoint.id === id))
        if (endpointToRemove.type === 'old') {
            endpointToRemove.type = 'removed'
        } else if (endpointToRemove.type === 'new') {
            newEndpoints = newEndpoints.filter((endpoint) => (endpoint.id !== id))
        }

        validate(newEndpoints, entities)
        validateNewEndpoint(newVerb, newPath, newEndpoints)
        setEndpoints(newEndpoints)
    }

    const addEndpoint = () => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        newEndpoints.push({
            id: uuidv4(),
            type: "new",
            http_verb: newVerb,
            verb: newVerb,
            path: newPath,
            output: {nodeType: "primitive", value: "nothing"},
            output_error: {nodeType: "primitive", value: "nothing"},
            responses: []
        })

        validate(newEndpoints, entities)
        validateNewEndpoint(newVerb, newPath, newEndpoints)
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
            root: {nodeType: "primitive", value: "nothing"},
            name: newEntity,
            collision: false,
            is_referenced: false,
            auth: "no_auth"
        })
        validateNewEntity(newEntity, newEntities)
        validate(endpoints, newEntities)
        setEntities(newEntities)
    }

    const updateNewPath = (e) => {
        setNewPath(e.target.value)
        validateNewEndpoint(newVerb, e.target.value, endpoints)
    }

    const updateNewVerb = (e) => {
        setNewVerb(e.target.value)
        validateNewEndpoint(e.target.value, newPath, endpoints)
    }

    const updateEntity = (id, newEntity) => {
        const indexToUpdate = entities.findIndex((entity) => (entity.id === id))
        const newEntities = [
            ...entities.slice(0, indexToUpdate),
            newEntity,
            ...entities.slice(indexToUpdate + 1),
        ]

        validate(endpoints, newEntities)
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
        validate(endpoints, newEntities)
        setEntities(newEntities)
    }

    useEffect(() => {
        console.log({ serializedEndpoints })
        const parsed_endpoints = JSON.parse(serializedEndpoints)

        parsed_endpoints.forEach((endpointData) => {
            endpointData.type = "old"
            endpointData.id = uuidv4()
            endpointData.collision = false

            endpointData.original_path = endpointData.path
            endpointData.original_verb = endpointData.verb

            const parsed_output = deserialize(endpointData.output)
            endpointData.original_output = parsed_output
            endpointData.output = parsed_output

            const parsed_output_error = deserialize(endpointData.output_error)
            endpointData.original_output_error = parsed_output_error
            endpointData.output_error = parsed_output_error

            endpointData.original_note = endpointData.note
            endpointData.original_responses = endpointData.responses
        })
        console.log({parsed_endpoints})
        setEndpoints(parsed_endpoints)

        console.log({ serializedEntities })

        const parsed_entities = JSON.parse(serializedEntities)

        parsed_entities.forEach((entityData) => {
            entityData.type = "old"
            entityData.id = uuidv4()

            const parsed_root = deserialize(entityData.root)
            entityData.original_root = parsed_root
            entityData.root = parsed_root

            entityData.original_name = entityData.name
            entityData.collision = false
            entityData.is_referenced = true
        })
        checkEntitiesReferences(parsed_endpoints, parsed_entities)
        console.log({parsed_entities})
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
                newPath={newPath}
                updateNewPath={updateNewPath}
                addEndpointDisabled={addEndpointDisabled}
            />
            <EntityList
                entities={entities}
                updateEntity={updateEntity}
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
