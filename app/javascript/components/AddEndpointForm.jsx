import React, {useRef, useState} from 'react'
import {createRoot} from "react-dom/client";
import JSONSchemaForm from "~/components/JSONSchemaForm.jsx";

const AddEndpointForm = () => {
    const [verb, setVerb] = useState("verb_get")
    const [url, setUrl] = useState("/resource")
    const ref = useRef(null)

    const addEndpoint = () => {
        const insertBeforeMe = ref.current.parentElement.parentElement.parentElement.parentElement;
        const insertInMe = ref.current.parentElement.parentElement.parentElement.parentElement.parentElement;

        const template = document.querySelector("#empty-endpoint");
        const clone = template.content.cloneNode(true);

        const verbSelect = clone.querySelector("select[name='version[endpoints_attributes][][http_verb]']")
        verbSelect.value = verb

        const urlInput = clone.querySelector("input[name='version[endpoints_attributes][][url]']")
        urlInput.value = url

        const div = clone.querySelector(".react-json-schema")
        div.setAttribute("data-initial-root", "string");

        insertInMe.insertBefore(clone, insertBeforeMe)

        const dataset = div.dataset
        const root = createRoot(div)
        root.render(<JSONSchemaForm {...dataset}/>)
    }

    return (
        <div ref={ref}>
            <select onChange={(e) => {
                setVerb(e.target.value)
            }}>
                <option value="verb_get" selected={verb === "verb_get"}>GET</option>
                <option value="verb_post" selected={verb === "verb_post"}>POST</option>
                <option value="verb_delete" selected={verb === "verb_delete"}>DELETE</option>
                <option value="verb_put" selected={verb === "verb_put"}>PUT</option>
                <option value="verb_patch" selected={verb === "verb_patch"}>PATCH</option>
            </select>
            <input type="text" value={url} onChange={(e) => {
                setUrl(e.target.value)
            }}/>
            <button type="button" onClick={addEndpoint}>Add</button>
        </div>
    )
}

export default AddEndpointForm




