import React from 'react'
import EntityDiff from "@/components/EntityDiff.jsx";
import EntityRemoved from "@/components/EntityRemoved.jsx";

const Entity = ({entity, updateRoot, removeEntity, entities}) => {
    if (entity.type === 'removed') {
        return (<EntityRemoved
            entity={entity}
            updateRoot={updateRoot}
            removeEntity={removeEntity}
            entities={[]}
        />)
    }

    // if (endpoint.type === 'new') {
    //     return (<EndpointAdded
    //         endpoint={endpoint}
    //         remove={remove}
    //         updateName={updateName}
    //         updateInput={updateInput}
    //         updateOutput={updateOutput}
    //         entities={entities}
    //     />)
    // }

    return (<EntityDiff
        entity={entity}
        updateRoot={updateRoot}
        removeEntity={removeEntity}
        entities={[]}
    />)
}

export default Entity