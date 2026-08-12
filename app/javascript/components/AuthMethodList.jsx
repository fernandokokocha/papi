import React from 'react'
import AuthMethod from "@/components/AuthMethod.jsx";

const AuthMethodList = ({authMethods, updateAuthMethod, removeAuthMethod, addAuthMethod, authMethodError, newAuthMethod, updateNewAuthMethod}) => {
    return (
        <>
            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-8">Auth</div>

            <div className="flex flex-col gap-6">
                {authMethods.map((authMethod) => (
                    <div key={authMethod.id}>
                        <AuthMethod
                            authMethod={authMethod}
                            updateAuthMethod={updateAuthMethod}
                            removeAuthMethod={removeAuthMethod}
                        />
                    </div>
                ))}
            </div>

            <div className="text-xl font-semibold text-black uppercase tracking-wide mb-3 mt-8">Add Auth Method</div>

            <div className="grid grid-cols-2 gap-2">
                <div></div>
                <div>
                    <div className="border border-emerald-200 rounded-lg overflow-hidden">
                        <div className="bg-emerald-700 text-white px-4 py-3 text-sm font-mono flex items-center gap-2">
                            <input
                                type="text"
                                value={newAuthMethod}
                                onChange={updateNewAuthMethod}
                                className="bg-emerald-600 text-white text-xs rounded border border-emerald-500 px-2 py-0.5 flex-1 focus:outline-none"
                            />
                            <button
                                type="button"
                                onClick={addAuthMethod}
                                disabled={!!authMethodError}
                                className={authMethodError
                                    ? "text-xs bg-white/20 text-white/50 px-3 py-1 rounded cursor-not-allowed"
                                    : "text-xs bg-white text-emerald-700 hover:bg-emerald-50 px-3 py-1 rounded cursor-pointer font-medium"}
                            >
                                Add
                            </button>
                        </div>
                        {authMethodError && (
                            <div className="px-3 py-2 bg-emerald-50 text-xs text-red-600 border-t border-emerald-200">
                                {authMethodError}
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </>
    )
}

export default AuthMethodList
