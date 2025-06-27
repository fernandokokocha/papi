import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const EntityAdded = ({entity, updateRoot, removeEntity, entities}) => {
    return (
        <div className="entity-container added" key={entity.id}>
            <div className="entity-name-container">
                <div className="entity-name-placeholder">
                </div>
                <div className="entity-name">
                    {entity.name}
                    <input type="hidden"
                           value={entity.name}
                           name="version[entities_attributes][][name]"
                    />
                </div>
            </div>

            <div className="entity-root-container">
                <div className="entity-root">
                </div>
                <div className="entity-root">
                    <JSONSchemaForm
                        name="version[entities_attributes][][original_root]"
                        update={updateRoot}
                        root={entity.root}
                        id={entity.id}
                        entities={[]}
                    />
                </div>
            </div>
        </div>
    )
}

export default EntityAdded
