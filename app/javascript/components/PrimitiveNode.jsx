import React from 'react'
import TypeSelect from "~/components/TypeSelect.jsx";

const PrimitiveNode = ({value, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing}) => {
    return (
        <span className="primitive">
            <TypeSelect value={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path}
                        canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
        </span>
    )
}

export default PrimitiveNode
