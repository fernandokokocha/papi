import React from 'react'
import Value from "@/components/json_schema/Value.jsx";

const ObjectAttribute = ({name, optional, value, onChange, onDelete, onAdd, onToggleOptional, path, canBeDeleted, canBeNothing, entities}) => {
    const toggleClass = optional
        ? "bg-sky-600 text-white border border-sky-600"
        : "bg-white text-gray-500 border border-gray-300 hover:bg-gray-50"

    return (
        <div className="object-attribute">
            {name}
            <button type="button"
                    className={`${toggleClass} rounded px-1 mx-1 font-mono text-xs`}
                    aria-label={`Toggle optional for ${name}`}
                    aria-pressed={!!optional}
                    onClick={(e) => onToggleOptional(e, path)}>?</button>
            : <Value
            root={value}
            onChange={onChange}
            onDelete={onDelete}
            onAdd={onAdd}
            onToggleOptional={onToggleOptional}
            path={path}
            canBeDeleted={canBeDeleted}
            canBeNothing={canBeNothing}
            entities={entities}
        />
        </div>
    )
}

export default ObjectAttribute
