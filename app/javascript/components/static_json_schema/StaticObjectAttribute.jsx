import React from 'react'
import StaticValue from "@/components/static_json_schema/StaticValue.jsx";

const StaticObjectAttribute = ({name, value}) => {
    return (
        <div className="object-attribute">
            {name}: <StaticValue root={value}/>
        </div>
    )
}

export default StaticObjectAttribute
