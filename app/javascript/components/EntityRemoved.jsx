import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";

const EntityRemoved = ({entity, updateRoot, removeEntity, entities}) => {
    return (
        <div className="entity-container" key={entity.id}>
            <div className="entity-name-container">
                <div className="entity-name">
                    {entity.original_name}
                </div>
                <div className="entity-name removed">
                    {entity.original_name}
                </div>
            </div>
        </div>
    )
}

export default EntityRemoved
