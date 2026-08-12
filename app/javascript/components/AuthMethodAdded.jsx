import React from 'react'
import AuthMethodFields from "@/components/AuthMethodFields.jsx";

const AuthMethodAdded = ({authMethod, updateAuthMethod, removeAuthMethod}) => {
    const updateKind = (newKind) => {
        updateAuthMethod(authMethod.id, {...authMethod, kind: newKind})
    }

    const updateNote = (newNote) => {
        updateAuthMethod(authMethod.id, {...authMethod, note: newNote})
    }

    return (
        <div className="grid grid-cols-2 gap-2" key={authMethod.id}>
            <div></div>
            <div>
                <div className="border border-emerald-200 rounded-lg overflow-hidden">
                    <div className="bg-emerald-700 text-white px-4 py-2 text-sm font-mono flex items-center justify-between">
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
                        theme="emerald"
                    />
                </div>
            </div>
        </div>
    )
}

export default AuthMethodAdded
