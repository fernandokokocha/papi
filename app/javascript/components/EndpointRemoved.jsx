import React, {useState} from 'react'
import JSONSchemaForm from "~/components/JSONSchemaForm.jsx";
import {v4 as uuidv4} from 'uuid';

const EndpointRemoved = ({endpoint, remove, updateName}) => {
    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_url}`}
                </div>
                <div className="endpoint-name removed">
                    { endpoint.original_verb + " " + endpoint.original_url}
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">INPUT</div>
                <div className="endpoint-section">INPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    {/*< %= render "spec", diff: input_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name=""
                        initialRoot={endpoint.input}
                    />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT</div>
                <div className="endpoint-section">OUTPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    {/*<%= render "spec", diff: output_diff %>*/}
                </div>
                <div className="endpoint-root">
                    <JSONSchemaForm
                        name=""
                        initialRoot={endpoint.output}
                    />
                </div>
            </div>
        </div>
    )
}

export default EndpointRemoved
