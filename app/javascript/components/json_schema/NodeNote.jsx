import React, {useEffect, useRef, useState} from 'react'
import {noteAt, withNoteAt} from "@/helpers/schemaNotes.js";

const PANEL_WIDTH = 352

// Every card in the editor clips its overflow to keep its rounded corners, so an
// absolutely positioned panel gets cut off. Anchoring to the viewport escapes
// that without unpicking the corners of ten different cards.
const panelPosition = (badge) => {
    const box = badge.getBoundingClientRect()
    const room = document.documentElement.clientWidth - box.left - 8

    return {top: box.bottom + 4, left: box.left - Math.max(0, PANEL_WIDTH - room)}
}

const NodeNote = ({notes, updateNotes, path}) => {
    const badge = useRef(null)
    const panel = useRef(null)
    const [position, setPosition] = useState(null)
    const note = noteAt(notes, path)

    const close = () => setPosition(null)

    // Panels are viewport-anchored and know nothing of each other, so opening a
    // second one has to read as dismissing the first — which it does, because
    // clicking its badge lands outside this one.
    useEffect(() => {
        if (!position) return

        const onPointerDown = (e) => {
            if (panel.current && panel.current.contains(e.target)) return
            if (badge.current && badge.current.contains(e.target)) return
            close()
        }
        const onKeyDown = (e) => { if (e.key === "Escape") close() }

        document.addEventListener("mousedown", onPointerDown)
        document.addEventListener("keydown", onKeyDown)
        return () => {
            document.removeEventListener("mousedown", onPointerDown)
            document.removeEventListener("keydown", onKeyDown)
        }
    }, [position])

    if (!updateNotes) return null

    const toggle = () => setPosition(position ? null : panelPosition(badge.current))

    return (
        <span className="node-note">
            <button type="button"
                    ref={badge}
                    className={note ? "node-note-badge has-note" : "node-note-badge"}
                    aria-label={note ? "Edit note" : "Add note"}
                    aria-expanded={!!position}
                    title={note ? note.body : "Add a note"}
                    onClick={toggle}>i</button>
            {position && (
                <span className="node-note-editor" ref={panel} style={position}>
                    <textarea rows="3"
                              autoFocus
                              value={note ? note.body : ""}
                              placeholder="What should a reader know about this?"
                              onChange={(e) => updateNotes(withNoteAt(notes, path, e.target.value))}/>
                    <span className="node-note-hint">Clearing the text removes the note.</span>
                    <button type="button" className="node-note-done" onClick={close}>Done</button>
                </span>
            )}
        </span>
    )
}

export default NodeNote
