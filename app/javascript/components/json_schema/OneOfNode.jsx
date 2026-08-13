import React from 'react'
import Value from "@/components/json_schema/Value.jsx";
import TypeSelect from "@/components/json_schema/TypeSelect.jsx";

const namedType = (branch) => {
    if (branch.nodeType === "primitive" || branch.nodeType === "custom") return branch.value
    return null
}

const OneOfNode = ({branches, onChange, onDelete, onAdd, onToggleOptional, path, canBeDeleted, canBeNothing, entities, excludeTypes = [], notes, updateNotes}) => {
    const takenTypes = branches.map(namedType).filter(Boolean)

    const excludedFor = (branch) => {
        const excluded = excludeTypes.concat(takenTypes.filter(type => type !== namedType(branch)))
        if (branch.nodeType !== "oneOf") excluded.push("oneOf")
        return excluded
    }

    return (
        <div className="one-of">
            <TypeSelect
                value="oneOf"
                onChange={onChange}
                onDelete={onDelete}
                path={path}
                canBeDeleted={canBeDeleted}
                canBeNothing={canBeNothing}
                entities={entities} notes={notes} updateNotes={updateNotes}
                excludeTypes={excludeTypes}
            />
            (
            {
                branches.map((branch, index) => (
                    <div className="one-of-branch" key={index}>
                        <Value
                            root={branch}
                            onChange={onChange}
                            onDelete={onDelete}
                            onAdd={onAdd}
                            onToggleOptional={onToggleOptional}
                            path={path.concat(index)}
                            canBeDeleted={branches.length > 2}
                            canBeNothing={false}
                            entities={entities} notes={notes} updateNotes={updateNotes}
                            excludeTypes={excludedFor(branch)}
                        />
                    </div>
                ))
            }

            <div className="one-of-new-branch">
                <button type="button" className="new-branch-add" aria-label="Add branch" onClick={(e) => onAdd(e, path)}>+</button>
            </div>

            <div className="one-of-close">)</div>
        </div>
    )
}

export default OneOfNode
