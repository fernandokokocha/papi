import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";
import serialize from "@/helpers/serialize.js";

const EntityAdded = ({entity, updateEntity, removeEntity, entities}) => {
    const updateRoot = (newRoot) => {
        const newEntity = {
            ...entity,
            root: newRoot
        }
        updateEntity(entity.id, newEntity)
    }

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
                    <button type="button" onClick={(e) => removeEntity(entity.id)} disabled={entity.is_referenced}>x</button>
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


            <div className="entity-root-container">
                <div className="entity-root-placeholder"></div>
                <div className="entity-root">
                    <div className="spec">{serialize(entity.root)}</div>
                </div>
            </div>
        </div>
    )
}

export default EntityAdded
