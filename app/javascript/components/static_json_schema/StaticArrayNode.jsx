import React from 'react'
import StaticValue from "@/components/static_json_schema/StaticValue.jsx";

const StaticArrayNode = ({value}) => {
    return (
        <div className="array">
            [
            <div class="array-value">
                <StaticValue root={value}/>
            </div>
            ]
        </div>
    )
}

export default StaticArrayNode
