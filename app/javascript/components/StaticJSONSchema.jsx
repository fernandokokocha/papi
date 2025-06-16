import React from 'react'
import deserialize from "~/helpers/deserialize.js";
import StaticValue from "@/components/StaticValue.jsx";

const StaticJSONSchema = ({root}) => {
    const parsedRoot = deserialize(root)

    return (
        <StaticValue root={parsedRoot}/>
    )
}

export default StaticJSONSchema
