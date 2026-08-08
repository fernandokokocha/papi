export const entityNamesIn = (root) => {
    if (root.nodeType === "custom") return [root.value]
    if (root.nodeType === "object") return root.attributes.flatMap((oa) => entityNamesIn(oa.value))
    if (root.nodeType === "array") return entityNamesIn(root.value)
    if (root.nodeType === "oneOf") return root.branches.flatMap((branch) => entityNamesIn(branch))

    return []
}

export const namesThatWouldCloseACircle = (entities, target) => {
    const reaching = new Set([target])
    let grew = true

    while (grew) {
        grew = false
        entities.forEach((entity) => {
            if (reaching.has(entity.name)) return
            if (entityNamesIn(entity.root).some((name) => reaching.has(name))) {
                reaching.add(entity.name)
                grew = true
            }
        })
    }

    return [...reaching]
}
