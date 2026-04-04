import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const EntityDiff = ({entity, updateEntity, removeEntity, entities}) => {
    const updateRoot = (newRoot) => {
        updateEntity(entity.id, {...entity, root: newRoot})
    }

    return (
        <div className="grid grid-cols-2 gap-2" key={entity.id}>
            {/* Left — original read-only */}
            <div>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-violet-800 text-white px-4 py-2 text-sm font-mono">
                        {entity.name}
                    </div>
                    <div className="pl-2 py-2 bg-white border-b border-gray-200">
                        <StaticJSONSchema root={entity.root}/>
                    </div>
                </div>
            </div>

            {/* Right — editable */}
            <div>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-violet-800 text-white px-4 py-2 text-sm font-mono flex items-center justify-between">
                        <span>{entity.name}</span>
                        <input type="hidden" name="version[entities_attributes][][name]" value={entity.name}/>
                        <button
                            type="button"
                            onClick={() => removeEntity(entity.id)}
                            disabled={entity.is_referenced}
                            className={entity.is_referenced
                                ? "text-xs bg-white/10 text-white/40 px-2 py-0.5 rounded cursor-not-allowed"
                                : "text-xs bg-white/10 hover:bg-white/25 text-white px-2 py-0.5 rounded"}
                            title={entity.is_referenced ? "Referenced by an endpoint" : "Remove entity"}
                        >
                            Remove
                        </button>
                    </div>
                    <div className="pl-2 py-2 bg-white border-b border-gray-200">
                        <JSONSchemaForm
                            name="version[entities_attributes][][root]"
                            update={updateRoot}
                            root={entity.root}
                            id={entity.id}
                            entities={entities}
                        />
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EntityDiff
