import React from 'react'
import Value from "@/components/json_schema/Value.jsx";
import TypeSelect from "@/components/json_schema/TypeSelect.jsx";

const ArrayNode = ({value, onChange, onDelete, onAdd, path, canBeDeleted, canBeNothing, entities}) => {
    return (
        <div className="array">
            <TypeSelect
                value="array"
                onChange={onChange}
                onDelete={onDelete}
                onAdd={onAdd}
                path={path}
                canBeDeleted={canBeDeleted}
                canBeNothing={canBeNothing}
                entities={entities}
            />
            [
            <div class="array-value">
                <Value
                    root={value}
                    onChange={onChange}
                    onDelete={onDelete}
                    onAdd={onAdd}
                    path={path.concat(null)}
                    canBeDeleted={false}
                    canBeNothing={false}
                    entities={entities}
                />
            </div>
            ]
        </div>
    )
}

export default ArrayNode
