import React from 'react'
import StaticValue from "@/components/static_json_schema/StaticValue.jsx";

const StaticOneOfNode = ({branches}) => {
    return (
        <div className="one-of">
            (
            {
                branches.map((branch, index) => (
                    <div className="one-of-branch" key={index}>
                        <StaticValue root={branch}/>
                    </div>
                ))
            }
            <div className="one-of-close">)</div>
        </div>
    )
}

export default StaticOneOfNode
