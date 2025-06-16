import React from 'react'
import StaticValue from "~/components/StaticValue.jsx";

const StaticObjectAttribute = ({name, value}) => {
    return (
        <div className="object-attribute">
            {name}: <StaticValue root={value}/>
        </div>
    )
}

export default StaticObjectAttribute
