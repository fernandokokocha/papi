import React from 'react'
import {createRoot} from 'react-dom/client'
import AddEndpointForm from '../components/AddEndpointForm.jsx'

document.addEventListener('turbo:load', () => {
    const container = document.getElementById('react-add-endpoint')
    if (!container) return;
    const root = createRoot(container)
    root.render(<AddEndpointForm />)
})
