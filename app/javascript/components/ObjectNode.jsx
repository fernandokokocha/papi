import React, {useState} from 'react'
import TypeSelect from "~/components/TypeSelect.jsx";
import ObjectAttribute from "~/components/ObjectAttribute.jsx";

const ObjectNode = ({onChange, onDelete, onAdd, attributes, path, canBeDeleted}) => {
    const [newName, setNewName] = useState("new")

    const addDisabled = attributes.some(({name}) => name === name)

    return (
        <div className="object">
            <TypeSelect value="object" onChange={onChange} onDelete={onDelete} path={path} canBeDeleted={canBeDeleted}/>
            {"{"}

            {attributes.length === 0 && <div style={{ backgroundColor: "red"}}>Add attrs</div>}

            {
                attributes.map(({name, value}) => (
                    <ObjectAttribute name={name}
                                     value={value}
                                     onChange={onChange}
                                     onDelete={onDelete}
                                     onAdd={onAdd}
                                     path={path.concat(name)}
                                     canBeDeleted={true}
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

