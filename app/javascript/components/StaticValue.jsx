import React from 'react'
import StaticPrimitiveNode from "~/components/StaticPrimitiveNode.jsx";
import StaticObjectNode from "~/components/StaticObjectNode.jsx";
import StaticArrayNode from "~/components/StaticArrayNode.jsx";

const StaticValue = ({root}) => {
    if (root.nodeType === "object") {
        return <StaticObjectNode attributes={root.attributes}/>
    }

    if (root.nodeType === "array") {
        return <StaticArrayNode value={root.value}/>
    }

    return (
        <StaticPrimitiveNode value={root.value}/>
    )
}

export default StaticValue
