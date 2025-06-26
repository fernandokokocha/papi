const trimEdgesAndWhitespace = (str) => {
    if (str.length <= 2) return '';
    return str.slice(1, -1).trim();
}

const splitByComma = (str) => {
    if (str.length === 0) return []
    const ret = []
    let deep = 0
    let tmp = ""
    for (let i = 0; i < str.length; i++) {
        if (str[i] === ",") {
            if (deep === 0) {
                const splitted = tmp.split(":")
                const rest = tmp.slice(splitted[0].length + 1)
                ret.push({
                    name: splitted[0].trim(),
                    value: deserialize(rest)
                })
                tmp = ""
            } else {
                tmp += str[i]
            }
        } else if (str[i] === "{") {
            deep += 1
            tmp += str[i]
        } else if (str[i] === "}") {
            deep -= 1
            tmp += str[i]
        } else {
            tmp += str[i]
        }
    }

    const splitted = tmp.split(":")
    const rest = tmp.slice(splitted[0].length + 1)
    ret.push({
        name: splitted[0].trim(),
        value: deserialize(rest)
    })

    return ret;
}

const deserialize = (root) => {
    root = root.trim()

    if (root.length === 0) {
        return {
            nodeType: "primitive",
            value: "nothing"
        }
    }

    if (root[0] === "{") {
        const inside = trimEdgesAndWhitespace(root)
        const attributes = splitByComma(inside)
        return {
            nodeType: "object",
            attributes: attributes
        }
    }

    if (root[0] === "[") {
        const newRoot = trimEdgesAndWhitespace(root)
        return {
            nodeType: "array",
            value: deserialize(newRoot)
        }
    }

    if (["string", "boolean", "number"].includes(root)) {
        return {
            nodeType: "primitive",
            value: root
        }
    }

    return {
        nodeType: "custom",
        value: root
    }
}

export default deserialize;