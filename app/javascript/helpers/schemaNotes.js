// The stored address of a note is the same path the editor threads through
// every node, serialized as JSON so Ruby and JS need no grammar between them.
export const pathKey = (path) => JSON.stringify(path)

export const noteAt = (notes, path) => {
  const key = pathKey(path)
  return (notes || []).find((note) => pathKey(note.path) === key)
}

export const withNoteAt = (notes, path, body) => {
  const key = pathKey(path)
  const others = (notes || []).filter((note) => pathKey(note.path) !== key)

  return body.trim() === "" ? others : [...others, {path, body}]
}
