import React from 'react'

const TypeSelect = ({value, onChange, onDelete, path, canBeDeleted, canBeNothing, entities}) => {
    let types = ["string", "number", "boolean", "object", "array"]
    if (canBeNothing) types.unshift("nothing")
    const custom_types = entities.filter((e) => (e.type !== 'removed')).map((e) => e.name);

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
            {canBeDeleted && <button type="button" onClick={(e) => onDelete(e, path)}>x</button>}
        </>
    )
}

export default TypeSelect
