import React from 'react'
import Entity from "@/components/Entity.jsx";

const EntityList = ({entities, updateEntity, removeEntity, addEntity, addEntityDisabled, newEntity, updateNewEntity}) => {
    return (
        <>
            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-8">Entities</div>

            <div className="flex flex-col gap-6">
                {entities.map((entity) => (
                    <Entity
                        key={entity.id}
                        entity={entity}
                        updateEntity={updateEntity}
                        removeEntity={removeEntity}
                        entities={entities}
                    />
                ))}
            </div>

            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-8">Add Entity</div>

            <div className="grid grid-cols-2 gap-2">
                <div></div>
                <div>
                    <div className="border border-emerald-200 rounded-lg overflow-hidden">
                        <div className="bg-emerald-700 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                            <input
                                type="text"
                                value={newEntity}
                                onChange={updateNewEntity}
                                className="bg-emerald-600 text-white text-xs rounded border border-emerald-500 px-2 py-0.5 flex-1 focus:outline-none"
                            />
                            <button
                                type="button"
                                onClick={addEntity}
                                disabled={addEntityDisabled}
                                className={addEntityDisabled
                                    ? "text-xs bg-white/20 text-white/50 px-3 py-1 rounded cursor-not-allowed"
                                    : "text-xs bg-white text-emerald-700 hover:bg-emerald-50 px-3 py-1 rounded cursor-pointer font-medium"}
                            >
                                Add
                            </button>
                        </div>
                        {addEntityDisabled && (
                            <div className="px-3 py-2 bg-emerald-50 text-xs text-red-600 border-t border-emerald-200">
                                This entity already exists
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </>
    )
}

export default EntityList
