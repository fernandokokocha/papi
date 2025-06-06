import React from 'react'
import {createRoot} from 'react-dom/client'
import JSONSchemaForm from '../components/JSONSchemaForm.jsx'

document.addEventListener('turbo:load', () => {
    const containers = document.getElementsByClassName('react-json-schema')
    Array.from(containers).forEach(container => {
        const dataset = container.dataset
        const root = createRoot(container)
        root.render(<JSONSchemaForm {...dataset}/>)
    })
})
