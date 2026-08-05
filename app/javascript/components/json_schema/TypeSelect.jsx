import React from 'react'

const TypeSelect = ({value, onChange, onDelete, path, canBeDeleted, canBeNothing, entities, excludeTypes = []}) => {
    let types = ["string", "number", "boolean", "object", "array", "oneOf"]
    if (canBeNothing) types.unshift("nothing")
    types = types.filter((type) => !excludeTypes.includes(type))
    const custom_types = entities
        .filter((e) => (e.type !== 'removed'))
        .map((e) => e.name)
        .filter((name) => !excludeTypes.includes(name));

    return (
        <>
            <select value={value} onChange={(e) => onChange(e, path)}>
                {
                    types.map((type) => (
                        <option key={type} value={type}>
                            {type}
                        </option>
                    ))
                }
                { custom_types.length > 0 && (
                    <hr/>
                )}
                { custom_types.map(ct => (
                    <option key={ct} value={ct}>
                        {ct}
                    </option>
                )) }
            </select>
            {canBeDeleted && <button type="button" className="node-delete" aria-label="Remove" onClick={(e) => onDelete(e, path)}>×</button>}
        </>
    )
}

export default TypeSelect
