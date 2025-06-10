import React from 'react'
import ObjectNode from "~/components/ObjectNode.jsx";
import ArrayNode from "~/components/ArrayNode.jsx";
import PrimitiveNode from "~/components/PrimitiveNode.jsx";

const Value = ({root, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing}) => {
    if (root.nodeType === "object") {
        return <ObjectNode onChange={onChange} onDelete={onDelete} onAdd={onAdd} attributes={root.attributes} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
    }

    if (root.nodeType === "array") {
        return <ArrayNode value={root.value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
    }

    return (
        <PrimitiveNode value={root.value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
    )
}

export default Value
