import React from 'react'
import {createRoot} from 'react-dom/client'
import EndpointList from "~/components/EndpointList.jsx";

document.addEventListener('turbo:load', () => {
    const container = document.getElementById('react-endpoints')
    if (!container) return;
    const dataset = container.dataset
    const root = createRoot(container)
    root.render(<EndpointList {...dataset}/>)
})
