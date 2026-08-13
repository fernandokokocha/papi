import React, {useState} from 'react'
import Value from "@/components/json_schema/Value.jsx";
import serialize from "@/helpers/serialize.js";
import deserialize from "@/helpers/deserialize.js";
import findByPath from "@/helpers/findByPath.js";

const PRIMITIVE_KINDS = ["string", "number", "boolean"]
const SCALAR_TYPES = ["nothing", ...PRIMITIVE_KINDS]

const unusedBranch = (branches) => {
    const taken = branches.filter(b => b.nodeType === "primitive").map(b => b.value)
    const kind = PRIMITIVE_KINDS.find(k => !taken.includes(k))

    if (kind) return {nodeType: "primitive", value: kind}
    return {nodeType: "object", attributes: []}
}

const JSONSchemaForm = ({root, name, update, id, entities, excludeTypes = [], canBeNothing = false, notes, updateNotes, notesName}) => {
    const serializedRoot = serialize(root);

    const removeNode = (e, path) => {
        e.preventDefault()

        const lastElement = path.slice(-1)[0]
        const parentPath = path.slice(0, -1)
        let newRoot = JSON.parse(JSON.stringify(root));
        const parent = findByPath(newRoot, parentPath);

        if (typeof lastElement === "number") {
            parent.branches = parent.branches.filter((_, index) => index !== lastElement)
        } else {
            parent.attributes = parent.attributes.filter(attr => attr.name !== lastElement)
        }

        update(newRoot)
    }

    const toggleOptional = (e, path) => {
        e.preventDefault()

        const lastElement = path.slice(-1)[0]
        const parentPath = path.slice(0, -1)
        let newRoot = JSON.parse(JSON.stringify(root));
        const parent = findByPath(newRoot, parentPath);
        const attribute = parent.attributes.find(attr => attr.name === lastElement)

        attribute.optional = !attribute.optional

        update(newRoot)
    }

    const addNode = (e, path, name) => {
        e.preventDefault()

        let newRoot = JSON.parse(JSON.stringify(root));
        const current = findByPath(newRoot, path);

        if (current.nodeType === "oneOf") {
            current.branches.push(unusedBranch(current.branches))
        } else {
            current.attributes.push({name, optional: false, value: {nodeType: "primitive", value: "string"}})
        }

        update(newRoot)
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
        } else if (e.target.value === "oneOf") {
            current.nodeType = "oneOf";
            current.branches = [
                {nodeType: "primitive", value: "string"},
                {nodeType: "primitive", value: "number"}
            ]
        } else if (SCALAR_TYPES.includes(e.target.value)) {
            current.nodeType = "primitive";
            current.value = e.target.value;
        } else {
            current.nodeType = "custom";
            current.value = e.target.value;
        }

        update(newRoot)
    }

    return (
        <div className="json-schema">
            <input type="hidden"
                   name={name}
                   value={serializedRoot}>
            </input>
            {notesName && (notes || []).map((note, index) => (
                <React.Fragment key={JSON.stringify(note.path)}>
                    <input type="hidden" name={`${notesName}[${index}][path]`} value={JSON.stringify(note.path)}/>
                    <input type="hidden" name={`${notesName}[${index}][body]`} value={note.body}/>
                </React.Fragment>
            ))}
            <Value
                root={root}
                onChange={changeType}
                onDelete={removeNode}
                onAdd={addNode}
                onToggleOptional={toggleOptional}
                path={[]}
                canBeDeleted={false}
                canBeNothing={canBeNothing}
                entities={entities}
                excludeTypes={excludeTypes}
                notes={notes}
                updateNotes={updateNotes}
            />
        </div>
    )
}

export default JSONSchemaForm
