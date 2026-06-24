// Swagger/OpenAPI-style HTTP verb color code.
// Mirrors app/views/endpoints/_verb_badge.html.erb so the candidate form and the
// version view share one color language. Classes are complete literal strings so
// Tailwind can see them at build time (never interpolate color names into classes).

const FROM_HTTP_VERB = {
    verb_get: "GET",
    verb_post: "POST",
    verb_put: "PUT",
    verb_patch: "PATCH",
    verb_delete: "DELETE",
}

// Solid filled badge — for light backgrounds and against colored card headers.
const SOLID = {
    GET: "bg-blue-500 text-white",
    POST: "bg-emerald-500 text-white",
    PUT: "bg-amber-500 text-white",
    PATCH: "bg-teal-500 text-white",
    DELETE: "bg-red-500 text-white",
}

// Editable <select> sitting inside a dark/colored card header.
const SELECT = {
    GET: "bg-blue-600 text-white border-blue-400",
    POST: "bg-emerald-600 text-white border-emerald-400",
    PUT: "bg-amber-600 text-white border-amber-400",
    PATCH: "bg-teal-600 text-white border-teal-400",
    DELETE: "bg-red-600 text-white border-red-400",
}

// Accepts either the http_verb enum ("verb_get") or the human label ("GET").
export const verbLabel = (verb) => FROM_HTTP_VERB[verb] ?? verb
export const verbSolidClass = (verb) => SOLID[verbLabel(verb)] ?? ""
export const verbSelectClass = (verb) => SELECT[verbLabel(verb)] ?? ""
