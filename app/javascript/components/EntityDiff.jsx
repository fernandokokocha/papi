import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";
import serialize from "@/helpers/serialize.js";

const EntityDiff = ({entity, updateEntity, removeEntity, entities}) => {
    const updateRoot = (newRoot) => {
        const newEntity = {
            ...entity,
            root: newRoot
        }
        updateEntity(entity.id, newEntity)
    }

    return (
        <div className="entity-container" key={entity.id}>
            <div className="entity-name-container">
                <div className="entity-name">
                    {entity.name}
                </div>
                <div className="entity-name">
                    {entity.name}
                    <input type="hidden"
                           name="version[entities_attributes][][name]"
                           value={entity.name}
                    />
                    {/*<input type="hidden" value={entity.id} name="version[entities_attributes][][id]" />*/}
                    <button type="button" onClick={(e) => removeEntity(entity.id)} disabled={entity.is_referenced}>x
                    </button>
                </div>
            </div>

            <div className="entity-root-container">
                <div className="entity-root">
                    <StaticJSONSchema root={entity.original_root}/>
                </div>
                <div className="entity-root">
                    <JSONSchemaForm
                        name="version[entities_attributes][][original_root]"
                        update={updateRoot}
                        root={entity.root}
                        id={entity.id}
                        entities={entities}
                    />
                </div>
            </div>

            <div className="entity-root-container">
                <div className="entity-root">
                    <div className="spec">{serialize(entity.original_root)}</div>
                </div>
                <div className="entity-root">
                    <div className="spec">{serialize(entity.root)}</div>
                </div>
            </div>
        </div>
    )
}

export default EntityDiff