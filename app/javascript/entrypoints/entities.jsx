import React from 'react'
import {createRoot} from 'react-dom/client'
import EntityList from "~/components/EntityList.jsx";

document.addEventListener('turbo:load', () => {
    const container = document.getElementById('react-entities')
    if (!container) return;
    const dataset = container.dataset
    const root = createRoot(container)
    root.render(<EntityList {...dataset}/>)
})
