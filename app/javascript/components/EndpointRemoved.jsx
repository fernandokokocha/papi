import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";
import VerbBadge from "@/components/VerbBadge.jsx";

const sectionHeader = "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRow = "px-3 py-2 bg-white border-b border-gray-200 text-sm text-gray-700"
const contentRowPl = "pl-2 py-2 bg-white border-b border-gray-200"

const EndpointRemoved = ({endpoint, restore}) => {
    return (
        <div className="grid grid-cols-2 gap-2">
            {/* Left — original read-only */}
            <div>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-sky-900 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                        <VerbBadge verb={endpoint.original_verb}/>
                        <span className="truncate">{endpoint.original_path}</span>
                    </div>
                    <div className={sectionHeader}>Note</div>
                    <div className={contentRow}>{endpoint.original_note || <span className="text-gray-400 italic">—</span>}</div>
                    <div className={sectionHeader}>Responses</div>
                    <div className={contentRowPl}>
                        {endpoint.original_responses.length === 0
                            ? <span className="text-xs text-gray-400 italic">—</span>
                            : endpoint.original_responses.map((r) => (
                                <div key={r.code} className="border border-gray-200 rounded bg-white p-2 mb-2">
                                    <div className="text-sm text-gray-700">
                                        <span className="font-mono text-gray-500">{r.code}</span>{r.note ? `: ${r.note}` : ""}
                                    </div>
                                    <div className="pl-2 pt-1"><StaticJSONSchema root={r.output}/></div>
                                </div>
                            ))
                        }
                    </div>
                </div>
            </div>

            {/* Right — removed indicator */}
            <div>
                <div className="border border-red-200 rounded-lg overflow-hidden">
                    <div className="bg-red-600 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                        <VerbBadge verb={endpoint.original_verb}/>
                        <span className="line-through opacity-70 truncate">{endpoint.original_path}</span>
                        <button
                            type="button"
                            onClick={() => restore(endpoint.id)}
                            className="text-xs bg-white/10 hover:bg-white/25 text-white px-2 py-0.5 rounded ml-auto shrink-0"
                        >
                            Bring back
                        </button>
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
