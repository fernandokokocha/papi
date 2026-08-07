export const paramKinds = ["string", "number", "boolean"]

const PARAM_TOKEN = /:([A-Za-z_][A-Za-z0-9_]*)/g

export const paramNames = (path) => [...path.matchAll(PARAM_TOKEN)].map((m) => m[1])

export const paramsOf = (path, kinds) =>
    paramNames(path).map((name) => ({name: name, kind: kinds[name] || "string"}))

export const hasDuplicateParams = (path) => {
    const names = paramNames(path)
    return names.length !== new Set(names).size
}
