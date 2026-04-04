import React from 'react'

const EntityRemoved = ({entity}) => {
    return (
        <div className="grid grid-cols-2 gap-2" key={entity.id}>
            <div>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-violet-800 text-white px-4 py-2 text-sm font-mono">
                        {entity.original_name}
                    </div>
                </div>
            </div>
            <div>
                <div className="border border-red-200 rounded-lg overflow-hidden">
                    <div className="bg-red-600 text-white px-4 py-2 text-sm font-mono line-through opacity-70">
                        {entity.original_name}
                    </div>
                    <div className="px-3 py-4 bg-red-50 text-sm text-red-600 text-center">
                        Removed
                    </div>
                </div>
            </div>
        </div>
    )
}

export default EntityRemoved
