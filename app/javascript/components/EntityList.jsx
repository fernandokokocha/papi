import React from 'react'
import Entity from "@/components/Entity.jsx";

const EntityList = ({entities, updateRoot}) => {
    return (
        <>
            <div className="section">Entities</div>
            {entities.map((entity) => <Entity entity={entity}
                                              updateRoot={updateRoot}
                                              entities={entities}/>)}
        </>)
}

export default EntityList
