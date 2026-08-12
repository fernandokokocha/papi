import React from 'react'
import {authKinds} from "@/helpers/authKinds.js";

const themes = {
    slate: {
        sectionHeader: "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide",
        wrapper: "px-3 py-2 bg-white border-b border-gray-200",
        select: "border border-gray-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-slate-500 bg-white",
        textarea: "border border-gray-300 rounded px-2 py-1 text-sm w-full focus:outline-none focus:ring-1 focus:ring-slate-500 resize-y bg-white",
    },
    emerald: {
        sectionHeader: "bg-emerald-50 border-t border-emerald-200 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide",
        wrapper: "px-3 py-2 bg-emerald-50 border-b border-emerald-200",
        select: "border border-emerald-300 rounded text-xs px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500 bg-white",
        textarea: "border border-emerald-300 rounded px-2 py-1 text-sm w-full focus:outline-none focus:ring-1 focus:ring-emerald-500 resize-y bg-white",
    },
}

const AuthMethodFields = ({authMethod, updateKind, updateNote, theme}) => {
    const t = themes[theme]

    return (
        <>
            <div className={t.sectionHeader}>Kind</div>
            <div className={t.wrapper}>
                <select
                    name="version[auth_methods_attributes][][kind]"
                    value={authMethod.kind}
                    onChange={(e) => updateKind(e.target.value)}
                    className={t.select}
                >
                    {authKinds.map((k) => (<option key={k} value={k}>{k}</option>))}
                </select>
            </div>
            <div className={t.sectionHeader}>Note</div>
            <div className={t.wrapper}>
                <textarea
                    name="version[auth_methods_attributes][][note]"
                    value={authMethod.note}
                    onChange={(e) => updateNote(e.target.value)}
                    rows="2"
                    className={t.textarea}
                />
            </div>
        </>
    )
}

export default AuthMethodFields
