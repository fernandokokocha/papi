import React from 'react'
import JSONSchemaForm from "@/components/json_schema/JSONSchemaForm.jsx";

const themes = {
    emerald: {
        sectionHeader: "bg-emerald-50 border-t border-emerald-200 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide",
        noteWrapper: "px-3 py-2 bg-emerald-50 border-b border-emerald-200",
        noteTextarea: "border border-emerald-300 rounded px-2 py-1 text-sm w-full focus:outline-none focus:ring-1 focus:ring-emerald-500 resize-y bg-white",
        responsesWrapper: "pl-2 py-2 bg-emerald-50 border-b border-emerald-200 space-y-3",
        responseCard: "border border-emerald-200 rounded bg-white p-2",
        responseNoteInput: "border border-gray-300 rounded px-2 py-0.5 text-xs flex-1 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white",
        responseSelect: "border border-gray-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white",
        addButton: "text-xs bg-emerald-600 hover:bg-emerald-700 text-white px-2 py-0.5 rounded",
    },
    sky: {
        sectionHeader: "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide",
        noteWrapper: "px-3 py-2 bg-white border-b border-gray-200",
        noteTextarea: "border border-gray-300 rounded px-2 py-1 text-sm w-full focus:outline-none focus:ring-1 focus:ring-sky-500 resize-y",
        responsesWrapper: "pl-2 py-2 bg-white border-b border-gray-200 space-y-3",
        responseCard: "border border-gray-200 rounded bg-white p-2",
        responseNoteInput: "border border-gray-300 rounded px-2 py-0.5 text-xs flex-1 focus:outline-none focus:ring-1 focus:ring-sky-500 bg-white",
        responseSelect: "border border-gray-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-sky-500 bg-white",
        addButton: "text-xs bg-sky-600 hover:bg-sky-700 text-white px-2 py-0.5 rounded",
    },
}

const ResponseList = ({
    endpoint,
    addResponse,
    removeResponse,
    updateResponseNote,
    updateResponseOutput,
    updateNote,
    responsesToAdd,
    newResponseCode,
    setNewResponseCode,
    entities,
    theme,
}) => {
    const t = themes[theme]

    return (
        <>
            <div className={t.sectionHeader}>Note</div>
            <div className={t.noteWrapper}>
                <textarea
                    name="version[endpoints_attributes][][note]"
                    value={endpoint.note}
                    onChange={(e) => updateNote(e.target.value)}
                    rows="3"
                    className={t.noteTextarea}
                />
            </div>
            <div className={t.sectionHeader}>Responses</div>
            <div className={t.responsesWrapper}>
                {endpoint.responses.map((r) => (
                    <div key={r.code} className={t.responseCard}>
                        <div className="flex items-center gap-2">
                            <span className="font-mono text-xs text-gray-500 shrink-0">{r.code}:</span>
                            <input
                                type="text"
                                value={r.note}
                                onChange={(e) => updateResponseNote(r.code, e.target.value)}
                                className={t.responseNoteInput}
                            />
                            <button type="button" onClick={() => removeResponse(r.code)} className="text-xs text-red-500 hover:text-red-700 shrink-0">×</button>
                            <input type="hidden" name={`version[endpoints_attributes][][responses][${r.code}][note]`} value={r.note}/>
                        </div>
                        <div className="pl-2 pt-2">
                            <JSONSchemaForm
                                name={`version[endpoints_attributes][][responses][${r.code}][output]`}
                                update={(newOutput) => updateResponseOutput(r.code, newOutput)}
                                root={r.output}
                                id={`${endpoint.id}-${r.code}`}
                                entities={entities}
                            />
                        </div>
                    </div>
                ))}
                <div className="flex items-center gap-2 pt-1">
                    <select
                        value={newResponseCode ?? ""}
                        onChange={(e) => setNewResponseCode(e.target.value)}
                        className={t.responseSelect}
                    >
                        {responsesToAdd.map((r) => (<option key={r} value={r}>{r}</option>))}
                    </select>
                    <button type="button" onClick={() => addResponse()} className={t.addButton}>Add</button>
                </div>
            </div>
        </>
    )
}

export default ResponseList
