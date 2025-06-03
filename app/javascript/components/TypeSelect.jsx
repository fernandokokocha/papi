import React from 'react'

const TypeSelect = ({value, onChange, onDelete, path, canBeDeleted}) => {
    return (
        <>
            <select onChange={(e) => onChange(e, path)}>
                {
                    ["string", "number", "boolean", "object", "array"].map((type) => (
                        <option value={type} selected={value === type}>
                            {type}
                        </option>
                    ))
                }
            </select>
            { canBeDeleted && <button type="button" onClick={(e) => onDelete(e, path)}>x</button> }
        </>
    )
}

export default TypeSelect
