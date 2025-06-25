import React from 'react'
import Value from "@/components/json_schema/Value.jsx";

const ObjectAttribute = ({name, value, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing}) => {
    return (
        <div className="object-attribute">
            {name}: <Value root={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
        </div>
    )
}

export default ObjectAttribute
