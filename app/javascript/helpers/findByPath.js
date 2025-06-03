const findByPath = (root, path) => {
    const pathCopy = path.slice()
    let current = root;
    while (pathCopy.length > 0) {
        const next = pathCopy.shift()
        if (next === null) {
            current = current.value
        } else {
            current = current.attributes.find(a => a.name === next).value
        }
    }

    return current;
}

export default findByPath;