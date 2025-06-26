import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";

const EndpointRemoved = ({endpoint, remove, updateName, updateInput, updateOutput}) => {
    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_url}`}
                </div>
                <div className="endpoint-name removed">
                    {endpoint.original_verb + " " + endpoint.original_url}
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">INPUT</div>
                <div className="endpoint-section">INPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                </div>
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.original_input} />
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT</div>
                <div className="endpoint-section">OUTPUT</div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                </div>
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.output} />
                </div>
            </div>
        </div>
    )
}

export default EndpointRemoved
