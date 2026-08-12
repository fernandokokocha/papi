import React from 'react'
import AuthMethodDiff from "@/components/AuthMethodDiff.jsx";
import AuthMethodRemoved from "@/components/AuthMethodRemoved.jsx";
import AuthMethodAdded from "@/components/AuthMethodAdded.jsx";

const AuthMethod = ({authMethod, updateAuthMethod, removeAuthMethod}) => {
    if (authMethod.type === 'removed') {
        return (<AuthMethodRemoved authMethod={authMethod}/>)
    }

    if (authMethod.type === 'new') {
        return (<AuthMethodAdded
            authMethod={authMethod}
            updateAuthMethod={updateAuthMethod}
            removeAuthMethod={removeAuthMethod}
        />)
    }

    return (<AuthMethodDiff
        authMethod={authMethod}
        updateAuthMethod={updateAuthMethod}
        removeAuthMethod={removeAuthMethod}
    />)
}

export default AuthMethod
