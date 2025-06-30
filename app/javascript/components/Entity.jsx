import React from 'react'
import EntityDiff from "@/components/EntityDiff.jsx";
import EntityRemoved from "@/components/EntityRemoved.jsx";
import EntityAdded from "@/components/EntityAdded.jsx";

const Entity = ({entity, updateEntity, removeEntity, entities}) => {
    if (entity.type === 'removed') {
        return (<EntityRemoved
            entity={entity}
            updateEntity={updateEntity}
            removeEntity={removeEntity}
            entities={[]}
        />)
    }

    if (entity.type === 'new') {
        return (<EntityAdded
            entity={entity}
            updateEntity={updateEntity}
            removeEntity={removeEntity}
            entities={[]}
        />)
    }

    return (<EntityDiff
        entity={entity}
        updateEntity={updateEntity}
        removeEntity={removeEntity}
        entities={[]}
    />)
}

export default Entity