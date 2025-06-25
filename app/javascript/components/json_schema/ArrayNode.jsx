import React from 'react'
import Value from "@/components/json_schema/Value.jsx";
import TypeSelect from "@/components/json_schema/TypeSelect.jsx";

const ArrayNode = ({value, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing}) => {
    return (
        <div className="array">
            <TypeSelect value="array" onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
            [
            <div class="array-value">
                <Value root={value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path.concat(null)} canBeDeleted={false} canBeNothing={false}/>
            </div>
            ]
        </div>
    )
}

export default ArrayNode
