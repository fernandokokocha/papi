import React from 'react'
import TypeSelect from "~/components/TypeSelect.jsx";

const PrimitiveNode = ({value, onChange, onDelete, onAdd, path, canBeDeleted}) => {
    return (
        <span className="primitive">
            <TypeSelect value={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted}/>
        </span>
    )
}

export default PrimitiveNode
