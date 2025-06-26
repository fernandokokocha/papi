import React from 'react'
import ObjectNode from "@/components/json_schema/ObjectNode.jsx";
import ArrayNode from "@/components/json_schema/ArrayNode.jsx";
import PrimitiveNode from "@/components/json_schema/PrimitiveNode.jsx";

const Value = ({root, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing, entities}) => {
    if (root.nodeType === "object") {
        return <ObjectNode
            onChange={onChange}
            onDelete={onDelete}
            onAdd={onAdd}
            attributes={root.attributes}
            path={path}
            canBeDeleted={canBeDeleted}
            canBeNothing={canBeNothing}
            entities={entities}
        />
    }

    if (root.nodeType === "array") {
        return <ArrayNode
            value={root.value}
            onChange={onChange}
            onDelete={onDelete}
            onAdd={onAdd}
            path={path}
            canBeDeleted={canBeDeleted}
            canBeNothing={canBeNothing}
            entities={entities}
        />
    }

    return (
        <PrimitiveNode
            value={root.value}
            onChange={onChange}
            onDelete={onDelete}
            onAdd={onAdd}
            path={path}
            canBeDeleted={canBeDeleted}
            canBeNothing={canBeNothing}
            entities={entities}
        />
    )
}

export default Value
