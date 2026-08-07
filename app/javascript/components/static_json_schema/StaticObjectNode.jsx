import React from 'react'
import StaticObjectAttribute from "@/components/static_json_schema/StaticObjectAttribute.jsx";

const StaticObjectNode = ({attributes}) => {
    return (
        <div className="object">
            {"{"}

            {
                attributes.map(({name, optional, value}) => (
                    <StaticObjectAttribute key={name}
                                           name={name}
                                           optional={optional}
                                           value={value}
                    />
                ))
            }

            {"}"}
        </div>
    )
}

export default StaticObjectNode

