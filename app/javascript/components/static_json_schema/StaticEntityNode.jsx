import React from 'react'

const StaticEntityNode = ({value}) => {
    return (
        <span className={`custom ${value}`}>
            {value}
        </span>
    )
}

export default StaticEntityNode
