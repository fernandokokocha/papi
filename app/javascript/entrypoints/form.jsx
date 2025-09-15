import React from 'react'
import {createRoot} from 'react-dom/client'
import Form from "@/components/Form.jsx";

document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('react-form')
    if (!container) return;
    const dataset = container.dataset
    const root = createRoot(container)
    root.render(<Form {...dataset}/>)
})
