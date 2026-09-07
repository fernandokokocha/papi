---
title: What OpenAPI Gets Wrong
summary: A dozen lines of nested YAML, or one line that says exactly the same thing.
---

Here is an order object, as OpenAPI wants it written:

~~~json
{
  "type": "object",
  "required": ["id", "customer"],
  "properties": {
    "id": { "type": "number" },
    "customer": { "$ref": "#/components/schemas/Customer" },
    "tags": { "type": "array", "items": { "type": "string" } }
  }
}
~~~

And here it is in Papi:

~~~ruby
"{id:number,customer:Customer,tags?:[string]}"
~~~

That is the whole schema. It is one string, in one column, and the database knows
nothing about its structure.

## The grammar, in full

There are six things to learn, and this is all of them:

~~~ruby
string | number | boolean | null   # primitives
{name:T,other?:T}                  # object; ? marks optional
[T]                                # array
(A|B)                              # one-of
Customer                           # a reference to a named entity
""                                 # nothing was declared
~~~

`Nothing` is **not** `null`. Absence and the JSON value `null` are different
things, and conflating them is one of the places OpenAPI leaks.

## Why one string

Every read parses the string into a node tree, every write serialises a tree back,
and the round trip is exact:

~~~ruby
tree = Schema::Parser.new("{id:number,tags?:[string]}").parse
tree.serialize == "{id:number,tags?:[string]}"  # => true
~~~

Nothing caches a parsed tree across a write. That rule costs a little speed on the
editor, which is the surface that can afford it.
