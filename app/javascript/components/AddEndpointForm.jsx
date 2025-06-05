import React, {useRef, useState} from 'react'
import {createRoot} from "react-dom/client";
import EndpointForm from "~/components/EndpointForm.jsx";

const emptyEndpoint = (verb, url) => {

}

const AddEndpointForm = () => {
    const [verb, setVerb] = useState("verb_get")
    const [url, setUrl] = useState("/resource")
    const ref = useRef(null)

    const addEndpoint = () => {
        const td = ref.current;
        const tr = td.parentElement;
        const tbody = tr.parentElement;

        const template = document.querySelector("#empty-endpoint");
        const clone = template.content.cloneNode(true);
        const div = clone.querySelector(".react-root")

        div.setAttribute("data-initial-root", "string");
        div.setAttribute("data-initial-verb", verb);
        div.setAttribute("data-initial-url", url);

        tbody.insertBefore(clone, tr)

        const dataset = div.dataset
        const root = createRoot(div)
        root.render(<EndpointForm {...dataset}/>)
    }

    return (
        <>
            <td ref={ref}></td>
            <td>
                <div className="lines-container">
                    <thead>
                    <tr>
                        <th>
                            <select onChange={(e) => {
                                setVerb(e.target.value)
                            }}>
                                <option value="verb_get" selected={verb === "verb_get"}>GET</option>
                                <option value="verb_post" selected={verb === "verb_post"}>POST</option>
                                <option value="verb_delete" selected={verb === "verb_delete"}>DELETE</option>
                                <option value="verb_put" selected={verb === "verb_put"}>PUT</option>
                                <option value="verb_patch" selected={verb === "verb_patch"}>PATCH</option>
                            </select>
                            <input type="text" value="/resource" value={url} onChange={(e) => {
                                setUrl(e.target.value)
                            }}/>
                            <button type="button" onClick={addEndpoint}>Add</button>
                        </th>
                    </tr>
                    </thead>
                </div>
            </td>
        </>
    )
}

export default AddEndpointForm




