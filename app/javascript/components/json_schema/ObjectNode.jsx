import React, {useState} from 'react'
import TypeSelect from "@/components/json_schema/TypeSelect.jsx";
import ObjectAttribute from "@/components/json_schema/ObjectAttribute.jsx";

const ObjectNode = ({onChange, onDelete, onAdd, attributes, path, canBeDeleted, canBeNothing}) => {
    const [newName, setNewName] = useState("new")

    const addDisabled = attributes.some(({name}) => name === newName)

    return (
        <div className="object">
            <TypeSelect value="object" onChange={onChange} onDelete={onDelete} path={path} canBeDeleted={canBeDeleted} canBeNothing={canBeNothing}/>
            {"{"}

            {attributes.length === 0 && <div className="alert object-attribute" style={{ backgroundColor: "red"}}>Add attrs</div>}

            {
                attributes.map(({name, value}) => (
                    <ObjectAttribute name={name}
                                     value={value}
                                     onChange={onChange}
                                     onDelete={onDelete}
                                     onAdd={onAdd}
                                     path={path.concat(name)}
                                     canBeDeleted={true}
                                     canBeNothing={false}
                    />
                ))
            }

            <div class="object-new-attribute">
                <input value={newName} onChange={(e) => {
                    setNewName(e.target.value)
                }}></input>
                <button type="button" onClick={(e) => onAdd(e, path, newName)} disabled={addDisabled}>+</button>

            </div>

            {"}"}
        </div>
    )
}

export default ObjectNode

