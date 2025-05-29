import React, {useState} from 'react'
import Value from "~/components/Value.jsx";

const EndpointForm = ({initialRoot, initialVerb, initialUrl}) => {
    // console.log({props})

    const [root, setRoot] = useState(initialRoot)
    const [verb, setVerb] = useState(initialVerb)
    const [url, setUrl] = useState(initialUrl)

    const updateRoot = (e) => {
        console.log(`UPDATE ROOT ${e}`)
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
                            <option value="http_get">GET</option>
                            <option value="http_post">POST</option>
                            <option value="http_delete">DELETE</option>
                            <option value="http_put">PUT</option>
                            <option value="http_patch">PATCH</option>
                        </select>
                        <input type="text"
                               value={url}
                               onChange={(e) => setUrl(e.target.value)}
                               name="version[endpoints_attributes][][http_url]">
                        </input>
                        <button type="button">x</button>
                    </th>
                </tr>
                </thead>
                <tbody>
                <tr>
                    <td>
                        <Value root={root} onChange={updateRoot} />
                        <input type="hidden"
                               name="version[endpoints_attributes][][original_endpoint_root]"
                               value={root}>
                        </input>
                    </td>
                </tr>
                </tbody>
            </table>
        </div>
    )
}

export default EndpointForm
