import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";

const sectionHeader = "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRow = "px-3 py-2 bg-white border-b border-gray-200 text-sm text-gray-700"
const contentRowPl = "pl-2 py-2 bg-white border-b border-gray-200"

const EndpointRemoved = ({endpoint}) => {
    return (
        <div className="grid grid-cols-2 gap-2" key={endpoint.id}>
            {/* Left — original read-only */}
            <div>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-sky-900 text-white px-4 py-3 text-sm font-mono">
                        {`${endpoint.original_verb} ${endpoint.original_path}`}
                    </div>
                    <div className={sectionHeader}>Note</div>
                    <div className={contentRow}>{endpoint.original_note || <span className="text-gray-400 italic">—</span>}</div>
                    <div className={sectionHeader}>Responses</div>
                    <div className={contentRowPl}>
                        {endpoint.original_responses.length === 0
                            ? <span className="text-xs text-gray-400 italic">—</span>
                            : endpoint.original_responses.map((r) => (
                                <div key={r.code} className="text-sm text-gray-700">
                                    <span className="font-mono text-gray-500">{r.code}</span>{r.note ? `: ${r.note}` : ""}
                                </div>
                            ))
                        }
                    </div>
                    <div className={sectionHeader}>Output</div>
                    <div className={contentRowPl}><StaticJSONSchema root={endpoint.output}/></div>
                    <div className={sectionHeader}>Output for Errors</div>
                    <div className={contentRowPl}><StaticJSONSchema root={endpoint.output_error}/></div>
                </div>
            </div>

            {/* Right — removed indicator */}
            <div>
                <div className="border border-red-200 rounded-lg overflow-hidden">
                    <div className="bg-red-600 text-white px-4 py-3 text-sm font-mono line-through opacity-70">
                        {`${endpoint.original_verb} ${endpoint.original_path}`}
                    </div>
                    <div className="px-3 py-4 bg-red-50 text-sm text-red-600 text-center">
                        Removed
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EndpointRemoved
