import React from 'react'

const DeletedEndpoint = ({ verb, url }) => {
    return (
        <div className="deleted-endpoint">
            <div className="new-version-form-container">
                <table className="new-version-form">
                    <thead>
                    <tr>
                        <th>{verb} {url}</th>
                    </tr>
                    </thead>
                </table>
            </div>
        </div>
    )
}

export default DeletedEndpoint
