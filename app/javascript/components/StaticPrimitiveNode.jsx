import React from 'react'

const StaticPrimitiveNode = ({value}) => {
    const caption = value === "nothing" ? "-" : value

    return (
        <span className={`primitive ${value}`}>
            {caption}
        </span>
    )
}

export default StaticPrimitiveNode
