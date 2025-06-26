import React from 'react'
import Entity from "@/components/Entity.jsx";

const EntityList = ({entities, updateRoot, removeEntity}) => {
    return (
        <>
            <div className="section">Entities</div>
            {entities.map((entity) => <Entity entity={entity}
                                              updateRoot={updateRoot}
                                              removeEntity={removeEntity}
                                              entities={entities}
            />)}
        </>)
}

export default EntityList
