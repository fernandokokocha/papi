import React, {useState} from 'react'
import {v4 as uuidv4} from "uuid";
import Entity from "@/components/Entity.jsx";

const EntityList = ({serializedEntities}) => {
    const parsed = JSON.parse(serializedEntities)
    parsed.forEach((entityData) => {
        entityData.type = "old"
        entityData.id = uuidv4()
        entityData.original_root = entityData.root
        entityData.collision = false
    })

    const updateRoot = (id, newRoot) => {
        const newEntities = JSON.parse(JSON.stringify(entities))
        const entityToUpdate = newEntities.find((entity) => (entity.id === id))
        entityToUpdate.root = newRoot

        // validate(newEndpoints)
        // validateNewEndpoint(newVerb, newUrl, newEndpoints)
        setEntities(newEntities)
    }

    const [entities, setEntities] = useState(parsed);

    return (
        <>
            <div className="section">Entities</div>
            {entities.map((entity) => <Entity entity={entity} updateRoot={updateRoot}/>)}
        </>)
}

export default EntityList
