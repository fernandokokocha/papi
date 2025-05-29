import React from 'react'
import {createRoot} from 'react-dom/client'
import EndpointForm from '../components/EndpointForm.jsx'

document.addEventListener('DOMContentLoaded', () => {
    const containers = document.getElementsByClassName('react-root')
    Array.from(containers).forEach(container => {
        const dataset = container.dataset
        const root = createRoot(container)
        root.render(<EndpointForm {...dataset}/>)
    })
})
