import React from 'react'
import ObjectNode from "~/components/ObjectNode.jsx";
import ArrayNode from "~/components/ArrayNode.jsx";
import PrimitiveNode from "~/components/PrimitiveNode.jsx";

const Value = ({root, onChange, onDelete, onAdd, path, canBeDeleted}) => {
    if (root.nodeType === "object") {
        return <ObjectNode onChange={onChange} onDelete={onDelete} onAdd={onAdd} attributes={root.attributes} path={path} canBeDeleted={canBeDeleted}/>
    }

    if (root.nodeType === "array") {
        return <ArrayNode value={root.value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted}/>
    }

    return (
        <PrimitiveNode value={root.value} onChange={onChange} onDelete={onDelete} onAdd={onAdd} path={path} canBeDeleted={canBeDeleted}/>
    )
}

export default Value
