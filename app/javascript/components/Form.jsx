import React, {useEffect, useState} from 'react'
import EndpointList from "@/components/EndpointList.jsx";
import EntityList from "@/components/EntityList.jsx";
import {v4 as uuidv4} from "uuid";
import deserialize from "@/helpers/deserialize.js";
import {entityNamesIn} from "@/helpers/entityReferences.js";
import serialize from "@/helpers/serialize.js";
import {hasDuplicateParams, identityPath, paramsOf} from "@/helpers/pathParams.js";

const isNewEndpointColliding = (verb, path, e) => {
    let newEndpointColliding = false
    e.filter((endpoint) => (endpoint.type !== 'removed'))
        .forEach((endpoint) => {
            const collidingWithNewEndpoint = (identityPath(endpoint.path) === identityPath(path) && endpoint.http_verb === verb)
            if (collidingWithNewEndpoint) {
                newEndpointColliding = true
            }
        })

    return newEndpointColliding;
}

const newEntityError = (newEntity, entities) => {
    if (!/^[A-Z]/.test(newEntity)) {
        return "An entity name must start with an uppercase letter"
    }

    const colliding = entities.filter((entity) => (entity.type !== 'removed'))
        .some((entity) => (entity.name === newEntity))

    return colliding ? "This entity already exists" : null
}

const checkEntitiesReferences = (endpoints, entities) => {
    entities.forEach((entity) => {
        entity.is_referenced = findCustomNameInEndpoints(endpoints, entity.name)
    })
}

const findCustomNameInEndpoints = (endpoints, name) => {
    return endpoints.some((endpoint) => (
        entityNamesIn(endpoint.input).includes(name) ||
        endpoint.responses.some((r) => entityNamesIn(r.output).includes(name))
    ))
}

const Form = ({serializedEndpoints, serializedEntities, comments}) => {
    const commentsMap = React.useMemo(
        () => (comments ? JSON.parse(comments) : {endpoints: {}, entities: {}}),
        [comments]
    )
    const [entities, setEntities] = useState([]);
    const [endpoints, setEndpoints] = useState([]);
    const [noCollisions, setNoCollisions] = useState(true);
    const [anyChanges, setAnyChanges] = useState(false);
    const [newPath, setNewPath] = useState("/resource")
    const [newVerb, setNewVerb] = useState("verb_get")
    const [addEndpointDisabled, setAddEndpointDisabled] = useState(() => isNewEndpointColliding(newVerb, newPath, endpoints))
    const [newEntity, setNewEntity] = useState("MyResource")
    const [entityError, setEntityError] = useState(() => newEntityError(newEntity, entities))

    const validateNewEndpoint = (verb, path, e) => {
        setAddEndpointDisabled(isNewEndpointColliding(verb, path, e))
    }

    const validateNewEntity = (newEntity, entities) => {
        setEntityError(newEntityError(newEntity, entities))
    }

    const validate = (endpointsToSend, entitiesToSend) => {
        let newNoCollisions = true;
        endpointsToSend
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .forEach((endpoint) => {
                const colliding = endpointsToSend.filter((otherEndpoint) => identityPath(otherEndpoint.path) === identityPath(endpoint.path) && otherEndpoint.http_verb === endpoint.http_verb)
                if (colliding.length > 1) {
                    newNoCollisions = false;
                    endpoint.collision = true;
                } else {
                    endpoint.collision = false;
                }

                if (endpoint.responses.length === 0) {
                    newNoCollisions = false;
                    endpoint.no_responses = true;
                } else {
                    endpoint.no_responses = false;
                }

                if (hasDuplicateParams(endpoint.path)) {
                    newNoCollisions = false;
                    endpoint.duplicate_params = true;
                } else {
                    endpoint.duplicate_params = false;
                }

                const queryNames = endpoint.queryParams.map((p) => p.name)
                if (queryNames.some((name) => name.trim() === "") || new Set(queryNames).size !== queryNames.length) {
                    newNoCollisions = false;
                    endpoint.bad_query_params = true;
                } else {
                    endpoint.bad_query_params = false;
                }
            })
        setNoCollisions(newNoCollisions)

        const serializedEndpointsToSend = JSON.stringify(endpointsToSend
            .filter((endpoint) => (endpoint.type !== 'removed'))
            .map((endpoint) => ({
                http_verb: endpoint.http_verb,
                verb: endpoint.verb,
                path: endpoint.path,
                params: paramsOf(endpoint.path, endpoint.paramKinds),
                query_params: [...endpoint.queryParams]
                    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))
                    .map((p) => ({name: p.name, kind: p.kind, required: p.required})),
                note: endpoint.note,
                input: serialize(endpoint.input),
                responses: [...endpoint.responses]
                    .sort((a, b) => Number(a.code) - Number(b.code))
                    .map((r) => ({code: r.code, note: r.note, output: serialize(r.output)})),
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

    const restoreEndpoint = (id) => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        const endpointToRestore = newEndpoints.find((endpoint) => (endpoint.id === id))
        endpointToRestore.type = 'old'
        endpointToRestore.http_verb = endpointToRestore.original_http_verb
        endpointToRestore.verb = endpointToRestore.original_verb
        endpointToRestore.path = endpointToRestore.original_path
        endpointToRestore.note = endpointToRestore.original_note
        endpointToRestore.input = JSON.parse(JSON.stringify(endpointToRestore.original_input))
        endpointToRestore.responses = JSON.parse(JSON.stringify(endpointToRestore.original_responses))
        endpointToRestore.paramKinds = {...endpointToRestore.original_paramKinds}
        endpointToRestore.queryParams = endpointToRestore.original_queryParams.map((p) => ({...p}))
        endpointToRestore.collision = false

        validate(newEndpoints, entities)
        validateNewEndpoint(newVerb, newPath, newEndpoints)
        setEndpoints(newEndpoints)
        checkEntitiesReferences(newEndpoints, entities)
    }

    const addEndpoint = () => {
        const newEndpoints = JSON.parse(JSON.stringify(endpoints))
        newEndpoints.push({
            id: uuidv4(),
            type: "new",
            http_verb: newVerb,
            verb: newVerb,
            path: newPath,
            paramKinds: {},
            queryParams: [],
            input: {nodeType: "primitive", value: "nothing"},
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
            root: {nodeType: "primitive", value: "string"},
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
        const parsed_endpoints = JSON.parse(serializedEndpoints)

        parsed_endpoints.forEach((endpointData) => {
            endpointData.type = "old"
            endpointData.id = uuidv4()
            endpointData.collision = false

            endpointData.original_path = endpointData.path
            endpointData.original_verb = endpointData.verb
            endpointData.original_http_verb = endpointData.http_verb
            endpointData.original_note = endpointData.note

            const kinds = Object.fromEntries(endpointData.params.map((p) => [p.name, p.kind]))
            endpointData.paramKinds = kinds
            endpointData.original_paramKinds = {...kinds}
            delete endpointData.params

            endpointData.queryParams = endpointData.query_params
            endpointData.original_queryParams = endpointData.query_params.map((p) => ({...p}))
            delete endpointData.query_params

            const parsed_input = deserialize(endpointData.input)
            endpointData.input = parsed_input
            endpointData.original_input = parsed_input

            const editable = endpointData.responses.map((r) => ({code: r.code, note: r.note, output: deserialize(r.output)}))
            const original = endpointData.responses.map((r) => ({code: r.code, note: r.note, output: deserialize(r.output)}))
            endpointData.responses = editable
            endpointData.original_responses = original
        })
        setEndpoints(parsed_endpoints)

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
        setEntities(parsed_entities)

        validateNewEndpoint(newVerb, newPath, parsed_endpoints)
        validateNewEntity(newEntity, parsed_entities)
    }, [])

    const disabled = !(noCollisions && anyChanges);
    const submitClass = disabled
        ? "bg-gray-100 text-gray-400 text-sm font-medium px-4 py-2 rounded cursor-not-allowed"
        : "bg-sky-600 hover:bg-sky-700 text-white text-sm font-medium px-4 py-2 rounded cursor-pointer"

    return (
        <>
            <div className="flex items-center gap-3 mb-6">
                <input type="submit"
                       name="commit"
                       value="Create Version"
                       className={submitClass}
                       disabled={disabled}
                />
                {!noCollisions && <span className="text-sm text-red-600">Resolve collisions before submitting</span>}
                {noCollisions && !anyChanges && <span className="text-sm text-gray-400">Make any changes to enable submit</span>}
            </div>
            <EndpointList
                serializedEndpoints={serializedEndpoints}
                entities={entities}
                endpoints={endpoints}
                removeEndpoint={removeEndpoint}
                restoreEndpoint={restoreEndpoint}
                updateEndpoint={updateEndpoint}
                addEndpoint={addEndpoint}
                updateNewVerb={updateNewVerb}
                newVerb={newVerb}
                newPath={newPath}
                updateNewPath={updateNewPath}
                addEndpointDisabled={addEndpointDisabled}
                comments={commentsMap.endpoints}
                edited={anyChanges}
            />
            <EntityList
                entities={entities}
                updateEntity={updateEntity}
                removeEntity={removeEntity}
                newEntity={newEntity}
                updateNewEntity={updateNewEntity}
                addEntity={addEntity}
                entityError={entityError}
                comments={commentsMap.entities}
                edited={anyChanges}
            />
        </>
    )
}

export default Form
