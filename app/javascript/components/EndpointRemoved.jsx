import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import serialize from "@/helpers/serialize.js";

const EndpointRemoved = ({endpoint}) => {
    return (
        <div className="endpoint-container" key={endpoint.id}>
            <div className="endpoint-name-container">
                <div className="endpoint-name">
                    {`${endpoint.original_verb} ${endpoint.original_path}`}
                </div>
                <div className="endpoint-name removed">
                    {endpoint.original_verb + " " + endpoint.original_path}
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
                <div className="endpoint-section">RESPONSES</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-responses-container">
                <div className="endpoint-responses">
                    <div>
                        {endpoint.original_responses.map((r) => (
                            <div>
                                <span className="line">{r.code}</span>:
                                <span className="">{r.note}</span>
                            </div>
                        ))}
                    </div>
                </div>
                <div className="endpoint-responses-placeholder"></div>
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

            <div className="endpoint-section-container">
                <div className="endpoint-section">OUTPUT FOR ERRORS</div>
                <div className="endpoint-section-placeholder"></div>
            </div>

            <div className="endpoint-root-container">
                <div className="endpoint-root">
                    <StaticJSONSchema root={endpoint.output_error}/>
                </div>
                <div className="endpoint-root">
                </div>
            </div>
        </div>
    )
}

export default EndpointRemoved
