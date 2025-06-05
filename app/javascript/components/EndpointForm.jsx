import React, {useState} from 'react'
import Value from "~/components/Value.jsx";
import serialize from "~/helpers/serialize.js";
import deserialize from "~/helpers/deserialize.js";
import findByPath from "~/helpers/findByPath.js";
import DeletedEndpoint from "~/components/DeletedEndpoint.jsx";

const EndpointForm = ({initialRoot, initialVerb, initialUrl}) => {
    const [root, setRoot] = useState(initialRoot)
    const [parsedRoot, setParsedRoot] = useState(deserialize(initialRoot))
    const [verb, setVerb] = useState(initialVerb)
    const [url, setUrl] = useState(initialUrl)
    const [deleted, setDeleted] = useState(false)

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

        current.attributes.push({ name, value: { nodeType: "primitive", value: "string"}})
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

    if (deleted) {
        return <DeletedEndpoint verb={verb} url={url}/>
    }

    return (
        <div className="new-version-form-container">
            <table className="new-version-form">
                <thead>
                <tr>
                    <th>
                        <select value={verb}
                                onChange={(e) => setVerb(e.target.value)}
                                name="version[endpoints_attributes][][http_verb]">
                            <option value="verb_get">GET</option>
                            <option value="verb_post">POST</option>
                            <option value="verb_delete">DELETE</option>
                            <option value="verb_put">PUT</option>
                            <option value="verb_patch">PATCH</option>
                        </select>
                        <input type="text"
                               value={url}
                               onChange={(e) => setUrl(e.target.value)}
                               name="version[endpoints_attributes][][url]">
                        </input>
                        <button type="button" onClick={() => {
                            setDeleted(true)
                        }}>x</button>
                    </th>
                </tr>
                </thead>
                <tbody>
                <tr>
                    <td>
                        <input type="hidden"
                               name="version[endpoints_attributes][][original_endpoint_root]"
                               value={root}>
                        </input>
                        <Value
                            root={parsedRoot}
                            onChange={changeType}
                            onDelete={removeNode}
                            onAdd={addNode}
                            path={[]}
                            canBeDeleted={false}
                        />
                    </td>
                </tr>
                </tbody>
            </table>
        </div>
    )
}

export default EndpointForm
