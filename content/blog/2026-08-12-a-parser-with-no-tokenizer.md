---
title: A Parser With No Tokenizer
summary: The schema parser is hand-written and deliberately loose. That is a decision, not an oversight.
---

There is no tokenizer, no grammar library, and no parser generator. A malformed
spec may raise a bare `RuntimeError` rather than be diagnosed politely.

## Splitting on commas

Attributes are separated by commas, and commas also appear inside nested objects.
The obvious answer is a real tokenizer. The answer here tracks brace depth and
stops:

~~~ruby
def split_by_comma(source)
  depth = 0
  source.each_char.with_object([ +"" ]) do |char, parts|
    case char
    when "{" then depth += 1
    when "}" then depth -= 1
    end

    if char == "," && depth.zero?
      parts << +""
    else
      parts.last << char
    end
  end
end
~~~

It tracks `{}` and nothing else, and that suffices: a comma can never appear inside
`[]` or `()` without braces around it. The simplification is load-bearing, not lazy.

## An attribute name is everything before its first colon

~~~ruby
name, _, value = attribute.partition(":")
~~~

Which means a colon in a name is not supported. Nobody has wanted one.

## One implementation, and it is Ruby's

The parser serves the diff, the validator, the mock server and the editor form
alike. The form renders every schema server-side and re-parses on each edit, so a
grammar change is one change and one set of specs, rather than a Ruby change, a
JavaScript change, and a slow afternoon finding where they disagree.

It matches a primitive by exact name. It used to match by prefix, which quietly
read an entity called `numberOfItems` back as `number`.

~~~json
{ "before": "number", "after": "numberOfItems" }
~~~

That bug is the whole argument for exact matching, and it is now a test.
