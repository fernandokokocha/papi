import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const Entity = ({entity, updateRoot}) => {
    return (
        <div className="entity-container" key={entity.id}>
            <div className="entity-name-container">
                <div className="entity-name">
                    {entity.name}
                </div>
                <input type="hidden"
                       name="version[entities_attributes][][name]"
                       value={entity.name}
                />
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
                    />
                </div>
            </div>
        </div>
    )
}

export default Entity