import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const EntityAdded = ({entity, updateEntity, removeEntity, entities, excludeTypes}) => {
    const updateRoot = (newRoot) => {
        updateEntity(entity.id, {...entity, root: newRoot})
    }

    const updateNotes = (schema_notes) => {
        updateEntity(entity.id, {...entity, schema_notes})
    }

    return (
        <div className="grid grid-cols-2 gap-2" key={entity.id}>
            <div></div>
            <div>
                <div className="border border-emerald-200 rounded-lg overflow-hidden">
                    <div className="bg-emerald-700 text-white px-4 py-2 text-sm font-mono flex items-center justify-between">
                        <span>{entity.name}</span>
                        <input type="hidden" value={entity.name} name="version[entities_attributes][][name]"/>
                        <button
                            type="button"
                            onClick={() => removeEntity(entity.id)}
                            disabled={entity.is_referenced}
                            className={entity.is_referenced
                                ? "text-xs bg-white/10 text-white/40 px-2 py-0.5 rounded cursor-not-allowed"
                                : "text-xs bg-white/10 hover:bg-white/25 text-white px-2 py-0.5 rounded"}
                        >
                            Remove
                        </button>
                    </div>
                    <div className="pl-2 py-2 bg-emerald-50 border-b border-emerald-200">
                        <JSONSchemaForm
                            name="version[entities_attributes][][root]"
                            update={updateRoot}
                            root={entity.root}
                            id={entity.id}
                            entities={entities}
                            excludeTypes={excludeTypes}
                            notes={entity.schema_notes}
                            updateNotes={updateNotes}
                            notesName="version[entities_attributes][][schema_notes_attributes]"
                        />
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EntityAdded
