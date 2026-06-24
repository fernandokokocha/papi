import React from 'react'
import {verbLabel, verbSolidClass} from "@/helpers/verbColors.js"

const VerbBadge = ({verb}) => (
    <span className={`inline-flex items-center justify-center shrink-0 min-w-14 px-1.5 py-0.5 rounded text-xs font-bold font-mono tracking-wider leading-none ring-1 ring-inset ring-white/25 ${verbSolidClass(verb)}`}>
        {verbLabel(verb)}
    </span>
)

export default VerbBadge
