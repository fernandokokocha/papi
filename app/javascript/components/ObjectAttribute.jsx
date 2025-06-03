import React from 'react'
import Value from "~/components/Value.jsx";

const ObjectAttribute = ({name, value, onChange, onDelete, onAdd, path, canBeDeleted}) => {
    return (
        <div className="object-attribute">
            {name}: <Value root={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted}/>
        </div>
    )
}

export default ObjectAttribute
