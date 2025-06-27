const serialize = (root) => {
    if (root.nodeType === "primitive") {
        if (root.value === "nothing") {
            return ""
        }
        return root.value
    }

    if (root.nodeType === "array") {
        return `[${serialize(root.value)}]`
    }

    if (root.nodeType === "object") {
        return `{${root.attributes.map(a => `${a.name}:${serialize(a.value)}`).join(",")}}`
    }

    if (root.nodeType === "custom") {
        return root.value;
    }
}

export default serialize