import React from 'react'

const CardComments = ({html, edited}) => {
    if (!html) return null
    const className = "card-comments w-1/2 ml-auto pl-1" + (edited ? " edited" : "")
    return (
        <div className={className}>
            <div dangerouslySetInnerHTML={{__html: html}} />
        </div>
    )
}

export default CardComments
