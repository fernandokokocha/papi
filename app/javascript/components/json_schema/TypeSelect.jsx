import React, {useContext} from 'react'
import EntitiesContext from "@/components/EntitiesContext.js";

const TypeSelect = ({value, onChange, onDelete, path, canBeDeleted, canBeNothing}) => {
    let types = ["string", "number", "boolean", "object", "array"]
    if (canBeNothing) types.unshift("nothing")
    const custom_types = useContext(EntitiesContext);

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
                { custom_types.length > 0 && (
                    <hr/>
                )}
                { custom_types.map(ct => (
                    <option value={ct} selected={value === ct}>
                        {ct}
                    </option>
                )) }
            </select>
            {canBeDeleted && <button type="button" onClick={(e) => onDelete(e, path)}>x</button>}
        </>
    )
}

export default TypeSelect
