import React from 'react'
import AuthMethodFields from "@/components/AuthMethodFields.jsx";

const sectionHeader = "bg-gray-200 border-t border-gray-300 px-3 py-1.5 text-xs font-semibold text-black uppercase tracking-wide"
const contentRow = "px-3 py-2 bg-white border-b border-gray-200 text-sm text-gray-700"

const AuthMethodDiff = ({authMethod, updateAuthMethod, removeAuthMethod}) => {
    const updateKind = (newKind) => {
        updateAuthMethod(authMethod.id, {...authMethod, kind: newKind})
    }

    const updateNote = (newNote) => {
        updateAuthMethod(authMethod.id, {...authMethod, note: newNote})
    }

    return (
        <div className="auth-method-diff" key={authMethod.id}>
            {/* Left — original read-only */}
            <div className="auth-method-diff-card border border-gray-200 rounded-lg overflow-hidden">
                <div className="bg-slate-700 text-white px-4 py-2 text-sm font-mono">
                    {authMethod.name}
                </div>
                <div className={sectionHeader}>Kind</div>
                <div className={`${contentRow} font-mono text-xs text-gray-800`}>{authMethod.original_kind}</div>
                <div className={sectionHeader}>Note</div>
                <div className={contentRow}>{authMethod.original_note || <span className="text-gray-400 italic">—</span>}</div>
            </div>

            {/* Right — editable */}
            <div className="auth-method-diff-card border border-gray-200 rounded-lg overflow-hidden">
                <div className="bg-slate-700 text-white px-4 py-2 text-sm font-mono flex items-center justify-between">
                    <span>{authMethod.name}</span>
                    <input type="hidden" name="version[auth_methods_attributes][][name]" value={authMethod.name}/>
                    <button
                        type="button"
                        onClick={() => removeAuthMethod(authMethod.id)}
                        disabled={authMethod.is_referenced}
                        className={authMethod.is_referenced
                            ? "text-xs bg-white/10 text-white/40 px-2 py-0.5 rounded cursor-not-allowed"
                            : "text-xs bg-white/10 hover:bg-white/25 text-white px-2 py-0.5 rounded"}
                        title={authMethod.is_referenced ? "Used by an endpoint" : "Remove auth method"}
                    >
                        Remove
                    </button>
                </div>
                <AuthMethodFields
                    authMethod={authMethod}
                    updateKind={updateKind}
                    updateNote={updateNote}
                    theme="slate"
                />
            </div>
        </div>
    )
}

export default AuthMethodDiff
