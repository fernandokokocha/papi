import React from 'react'
import Value from "@/components/json_schema/Value.jsx";
import TypeSelect from "@/components/json_schema/TypeSelect.jsx";

const ArrayNode = ({value, onChange, onDelete, onAdd, onToggleOptional, path, canBeDeleted, canBeNothing, entities, excludeTypes, notes, updateNotes}) => {
    return (
        <div className="array">
            <TypeSelect
                value="array"
                onChange={onChange}
                onDelete={onDelete}
                onAdd={onAdd}
                path={path}
                canBeDeleted={canBeDeleted}
                canBeNothing={canBeNothing}
                entities={entities} notes={notes} updateNotes={updateNotes}
                excludeTypes={excludeTypes}
            />
            [
            <div className="array-value">
                <Value
                    root={value}
                    onChange={onChange}
                    onDelete={onDelete}
                    onAdd={onAdd}
                    onToggleOptional={onToggleOptional}
                    path={path.concat(null)}
                    canBeDeleted={false}
                    canBeNothing={false}
                    entities={entities} notes={notes} updateNotes={updateNotes}
                    excludeTypes={excludeTypes}
                />
            </div>
            ]
        </div>
    )
}

export default ArrayNode
