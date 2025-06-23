import React from 'react'
import EndpointList from "@/components/EndpointList.jsx";
import EntityList from "@/components/EntityList.jsx";
import EntitiesContext from "@/components/EntitiesContext.js";

const Form = ({serializedEndpoints, serializedEntities}) => {
    const entities = JSON.parse(serializedEntities)
    const custom_names = entities.map((e) => e.name)
    console.log({ custom_names })

    return (
        <EntitiesContext value={custom_names}>
            <EndpointList serializedEndpoints={serializedEndpoints}/>
            <EntityList serializedEntities={serializedEntities}/>
        </EntitiesContext>
    )
}

export default Form
