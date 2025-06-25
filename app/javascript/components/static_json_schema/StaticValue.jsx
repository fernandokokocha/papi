import React from 'react'
import StaticPrimitiveNode from "@/components/static_json_schema/StaticPrimitiveNode.jsx";
import StaticObjectNode from "@/components/static_json_schema/StaticObjectNode.jsx";
import StaticArrayNode from "@/components/static_json_schema/StaticArrayNode.jsx";

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
