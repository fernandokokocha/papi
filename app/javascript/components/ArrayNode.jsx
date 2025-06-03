import React from 'react'
import Value from "~/components/Value.jsx";
import TypeSelect from "~/components/TypeSelect.jsx";

const ArrayNode = ({value, onChange, onDelete, onAdd, path, canBeDeleted}) => {
    return (
        <div className="array">
            <TypeSelect value="array" onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted}/>
            [
            <div class="array-value">
                <Value root={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path.concat(null)} canBeDeleted={false}/>
            </div>
            ]
        </div>
    )
}

export default ArrayNode
