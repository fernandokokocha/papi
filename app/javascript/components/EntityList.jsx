import React from 'react'
import Entity from "@/components/Entity.jsx";

const EntityList = ({entities, updateEntity, removeEntity, addEntity, addEntityDisabled, newEntity, updateNewEntity}) => {
    return (
        <>
            <div className="section">Entities</div>

            {entities.map((entity) => <Entity entity={entity}
                                              updateEntity={updateEntity}
                                              removeEntity={removeEntity}
                                              entities={entities}
            />)}

            <div className="section">Add entity</div>

            <div className="entity-container added">
                <div className="entity-name-container">
                    <div className="entity-name-placeholder">
                    </div>
                    <div className="entity-name added">
                        <input type="text" value={newEntity} onChange={updateNewEntity}/>
                        <button type="button" onClick={addEntity} disabled={addEntityDisabled}>Add</button>
                        {addEntityDisabled && <div className="alert">This entity already exists</div>}
                    </div>
                </div>
            </div>
        </>)
}

export default EntityList
