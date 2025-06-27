import React from 'react'
import deserialize from "@/helpers/deserialize.js";
import StaticValue from "@/components/static_json_schema/StaticValue.jsx";

const StaticJSONSchema = ({root}) => {
    return (
        <div className="json-schema">
            <StaticValue root={root}/>
        </div>
    )
}

export default StaticJSONSchema
