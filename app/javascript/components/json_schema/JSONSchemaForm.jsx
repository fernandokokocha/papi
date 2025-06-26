import React, {useState} from 'react'
import Value from "@/components/json_schema/Value.jsx";
import serialize from "@/helpers/serialize.js";
import deserialize from "@/helpers/deserialize.js";
import findByPath from "@/helpers/findByPath.js";

const JSONSchemaForm = ({root, name, update, id, entities}) => {
    const serializedRoot = serialize(root);
    console.log("JSONSchemaForm", { root, serializedRoot })

    const removeNode = (e, path) => {
        e.preventDefault()

        const lastElement = path.slice(-1)[0]
        const parentPath = path.slice(0, -1)
        let newRoot = JSON.parse(JSON.stringify(root));
        const parent = findByPath(newRoot, parentPath);

        parent.attributes = parent.attributes.filter(attr => attr.name !== lastElement)

        update(id, newRoot)
    }

    const addNode = (e, path, name) => {
        e.preventDefault()

        let newRoot = JSON.parse(JSON.stringify(root));
        const current = findByPath(newRoot, path);

        current.attributes.push({name, value: {nodeType: "primitive", value: "string"}})

        update(id, newRoot)
    }

    const changeType = (e, path) => {
        e.preventDefault()

        let newRoot = JSON.parse(JSON.stringify(root));
        const current = findByPath(newRoot, path);

        if (e.target.value === "object") {
            current.nodeType = "object";
            current.attributes = []
        } else if (e.target.value === "array") {
            current.nodeType = "array";
            current.value = {
                nodeType: "primitive",
                value: "string"
            }
        } else {
            current.nodeType = "primitive";
            current.value = e.target.value;
        }

        update(id, newRoot)
    }

    return (
        <>
            <input type="hidden"
                   name={name}
                   value={serializedRoot}>
            </input>
            <Value
                root={root}
                onChange={changeType}
                onDelete={removeNode}
                onAdd={addNode}
                path={[]}
                canBeDeleted={false}
                canBeNothing={true}
                entities={entities}
            />
        </>
    )
}

export default JSONSchemaForm
