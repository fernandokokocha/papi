import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import serialize from "@/helpers/serialize.js";

const EndpointRemoved = ({endpoint}) => {
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
                <div className="endpoint-section">NOTE</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-note-container">
                <div className="endpoint-note">{endpoint.original_note}</div>
                <div className="endpoint-note-placeholder"></div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">AUTH</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-note-container">
                <div className="endpoint-note">
                    <div className="endpoint-note">{endpoint.original_auth === "no_auth" ? "No auth" : "Bearer"}</div>
                </div>
                <div className="endpoint-note-placeholder"></div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">INPUT</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.original_input}/>
                </div>
                <div className="endpoint-root">
                </div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.original_input)}</div>
                </div>
                <div className="endpoint-root-placeholder">
                </div>
            </div>

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.output}/>
                </div>
                <div className="endpoint-root">
                </div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <div className="spec">{serialize(endpoint.original_output)}</div>
                </div>
                <div className="endpoint-root-placeholder">
                </div>
            </div>
        </div>
    )
}

export default EndpointRemoved
