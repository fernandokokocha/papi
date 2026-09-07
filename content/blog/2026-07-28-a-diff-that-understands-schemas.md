---
title: A Diff That Understands Schemas
summary: Reordering the keys of an object is not a change. Text diffs disagree, loudly.
---

Run a text diff over two versions of a spec and it will tell you that moving
`email` above `name` is a change. It is not. The two objects mean the same thing,
and a reviewer asked to look at them has been given busywork.

## Two equalities, two layers

*Semantic equivalence* asks whether two schemas mean the same thing. It matches
attributes by name and re-lays-out the before column into the after column's order.
A reordered object reads as `no_change`.

*Structural identity* asks whether the parser built the tree you wrote, in that
order. It stays strictly positional, and only the specs ask it:

~~~ruby
Schema::Parser.new("{a:string,b:number}").parse ==
  Schema::Parser.new("{b:number,a:string}").parse
# => false, and that is correct
~~~

Order is semantically meaningless but materially preserved: it drives diff line
order, example JSON key order, and the serialise round trip. Making the second
equality order-insensitive would only weaken the assertions that use it.

## What the reviewer sees

Two columns, padded with blank lines so before and after stay row-aligned:

~~~json
{
  "before": "{id:number,name:string}",
  "after":  "{id:number,name:string,email?:string}",
  "verdict": "added one optional attribute"
}
~~~

One row changed. Everything else is quiet, which is the point.
