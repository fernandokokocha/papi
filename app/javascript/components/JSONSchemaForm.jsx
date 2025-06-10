import React, {useState} from 'react'
import Value from "~/components/Value.jsx";
import serialize from "~/helpers/serialize.js";
import deserialize from "~/helpers/deserialize.js";
import findByPath from "~/helpers/findByPath.js";

const JSONSchemaForm = ({initialRoot, name}) => {
    const [root, setRoot] = useState(initialRoot)
    const [parsedRoot, setParsedRoot] = useState(deserialize(initialRoot))

    const removeNode = (e, path) => {
        e.preventDefault()

        const lastElement = path.slice(-1)[0]
        const parentPath = path.slice(0, -1)
        let newRoot = JSON.parse(JSON.stringify(parsedRoot));
        const parent = findByPath(newRoot, parentPath);

        parent.attributes = parent.attributes.filter(attr => attr.name !== lastElement)
        setParsedRoot(newRoot)

        const newRootString = serialize(newRoot)
        setRoot(newRootString)
    }

    const addNode = (e, path, name) => {
        e.preventDefault()

        let newRoot = JSON.parse(JSON.stringify(parsedRoot));
        const current = findByPath(newRoot, path);

        current.attributes.push({name, value: {nodeType: "primitive", value: "string"}})
        setParsedRoot(newRoot)

        const newRootString = serialize(newRoot)
        setRoot(newRootString)
    }

    const changeType = (e, path) => {
        e.preventDefault()

        let newRoot = JSON.parse(JSON.stringify(parsedRoot));
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

        setParsedRoot(newRoot)

        const newRootString = serialize(newRoot)
        setRoot(newRootString)
    }

    return (
        <>
            <input type="hidden"
                   name={name}
                   value={root}>
            </input>
            <Value
                root={parsedRoot}
                onChange={changeType}
                onDelete={removeNode}
                onAdd={addNode}
                path={[]}
                canBeDeleted={false}
                canBeNothing={true}
            />
        </>
    )
}

export default JSONSchemaForm
