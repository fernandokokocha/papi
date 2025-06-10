import React from 'react'

const TypeSelect = ({value, onChange, onDelete, path, canBeDeleted, canBeNothing}) => {
    let types = ["string", "number", "boolean", "object", "array"];
    if (canBeNothing) types.push("nothing")

    return (
        <>
            <select onChange={(e) => onChange(e, path)}>
                {
                    types.map((type) => (
                        <option value={type} selected={value === type}>
                            {type}
                        </option>
                    ))
                }
            </select>
            {canBeDeleted && <button type="button" onClick={(e) => onDelete(e, path)}>x</button>}
        </>
    )
}

export default TypeSelect
