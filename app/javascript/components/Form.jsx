import React from 'react'

const Form = () => (
    <div className="flex items-center gap-3 mb-6">
        <input type="submit"
               name="commit"
               value="Create Version"
               className="bg-gray-100 text-gray-400 text-sm font-medium px-4 py-2 rounded cursor-not-allowed"
               disabled
        />
    </div>
)

export default Form
