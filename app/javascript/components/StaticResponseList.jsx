import React from 'react'
import StaticJSONSchema from "@/components/static_json_schema/StaticJSONSchema.jsx";

const sectionHeader = "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRowPl = "pl-2 py-2 bg-white border-b border-gray-200"

const StaticResponseList = ({responses}) => {
    return (
        <>
            <div className={sectionHeader}>Responses</div>
            <div className={contentRowPl}>
                {responses.length === 0
                    ? <span className="text-xs text-gray-400 italic">—</span>
                    : responses.map((r) => (
                        <div key={r.code} className="border border-gray-200 rounded bg-white p-2 mb-2">
                            <div className="text-sm text-gray-700">
                                <span className="font-mono text-gray-500">{r.code}</span>{r.note ? `: ${r.note}` : ""}
                            </div>
                            <div className="pl-2 pt-1"><StaticJSONSchema root={r.output}/></div>
                        </div>
                    ))
                }
            </div>
        </>
    )
}

export default StaticResponseList
